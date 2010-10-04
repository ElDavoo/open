package Socialtext::WebDaemon;
# @COPYRIGHT@
use Moose;
use MooseX::AttributeHelpers;
use MooseX::StrictConstructor;

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$ENV{ST_CURRENT}/nlw/lib";
use Getopt::Long;
use Carp qw/carp croak/;

use Socialtext::Async;
use Socialtext::Log qw/st_log/;
use Socialtext::TimestampedWarnings;

use Socialtext::AppConfig;
use Socialtext::HTTP::Ports;
use Socialtext::HTTP::Cookie;

use Socialtext::Async;
use Socialtext::Async::HTTPD qw/http_server/;
use Socialtext::Async::WorkQueue;
use Socialtext::Async::Wrapper; # auto-exports

use Socialtext::Cache;
use Socialtext::User;
use Socialtext::User::Cache;
use Socialtext::User::Default::Factory;

use Socialtext::WebDaemon::Util; # auto-exports some stuff;
use Socialtext::WebDaemon::Request;

use namespace::clean -except => 'meta';

BEGIN {
    # {bz: 4151} - load LDAP code in the parent if that factory is enabled.
    if (Socialtext::AppConfig->user_factories  =~ /LDAP/ ||
        Socialtext::AppConfig->group_factories =~ /LDAP/)
    {
        require Socialtext::User::LDAP::Factory;
        require Socialtext::Group::LDAP::Factory;
    }

    # unbuffer stderr/stdout
    select STDERR; $|=1;
    select STDOUT; $|=1;
}

our $SINGLETON;
our $NAME; # don't set this, define a `name` constant in your module
our $PROC_NAME;

has 'host' => (is => 'rw', isa => 'Str', default => '127.0.0.1');
has 'port' => (is => 'rw', isa => 'Int');

has 'is_running' => (
    is => 'rw', isa => 'Bool',
    default => 1, writer => '_running'
);

has 'cv' => (
    is => 'ro', isa => 'AnyEvent::CondVar',
    default => sub { AE::cv() }
);

has 'stats' => (is => 'rw', isa => 'HashRef', default => sub {{}});

has 'shutdown_delay'     => (is => 'rw', isa => 'Num', default => 15);
has 'stats_period'       => (is => 'rw', isa => 'Num', default => 900);
has 'worker_ping_period' => (is => 'rw', isa => 'Num', default => 60);

has 'guards' => (
    is => 'ro', isa => 'HashRef',
    metaclass => 'Collection::Hash',
    provides => {
        delete => 'disable_guard',
    },
    default => sub {{}},
    clearer => '_destroy_guards'
);

use constant RequestClass => 'Socialtext::WebDaemon::Request';

# called by startup scripts
sub Configure {
    shift; # __PACKAGE__
    my $class = shift;
    my $default_port = shift;

    eval "require $class";
    croak $@ if $@;

    {
        no strict 'refs';
        croak "class '$class' needs a Name constant"
            unless *{$class."::Name"};
        croak "class '$class' needs a ProcName constant"
            unless *{$class."::ProcName"};
    }
    $NAME = $class->Name;
    $PROC_NAME = $class->ProcName;

    st_log->info("$PROC_NAME is starting up...");

    my %opts;
    GetOptions(
        \%opts,
        $class->Getopts(),
        'shutdown-delay=i',
        'port=i',
    );

    my %args = map { (my $k = $_) =~ tr/-/_/; $k => $opts{$_} } keys %opts;
    $args{port} ||= $default_port;
    unless (Socialtext::AppConfig->is_appliance) {
        $args{shutdown_delay} ||= 5.0;
        # change args for running under dev-env
        $class->ConfigForDevEnv(\%args);
    }

    Socialtext::Async::Wrapper->RegisterCoros();

    $0 = $PROC_NAME;
    $SINGLETON = $class->new(\%args);

    Socialtext::Async::Wrapper->RegisterAtFork(sub {
        $SINGLETON->at_fork;
    });

}

sub Run {
    my ($class, @args) = @_;

    try { $class->Configure(@args) }
    catch {
        carp "could not configure $class: $_";
    };

    try { $SINGLETON->run; }
    catch {
        carp "$PROC_NAME stopping due to exception: $_";
        st_log->error("$PROC_NAME stopping due to exception: $_");
    };

    st_log->info("$PROC_NAME done");
    exit 0;
}

# called by Run above.
sub run {
    my $self = shift;
    weaken $self;

    st_log()->info("$PROC_NAME starting on ".$self->host." port ".$self->port);

    worker_make_immutable();

    $self->guards->{server} = http_server $self->host, $self->port,
        unblock_sub { $self->_wrap_request(@_) };
    confess "Couldn't create server" unless $self->guards->{server};

    $self->guards->{stats_ticker} =
        AE::timer $self->stats_period, $self->stats_period,
        exception_wrapper { $self->stats_ticker() } "Ticker error";

    my $shutdown_handler = exception_wrapper {
        $self->shutdown()
    } "shutdown signal error";

    for my $sig (qw(TERM INT QUIT)) {
        $self->guards->{"sig_$sig"} = AE::signal $sig, $shutdown_handler;
    }

    $self->guards->{worker_pinger} =
        AE::timer $self->worker_ping_period, $self->worker_ping_period,
        exception_wrapper {
            try { 
                ping_worker();
                trace "Worker is OK!";
            }
            catch {
                trace "Worker is bad! $_";
            };
        } 'Worker Pinger error';

    inner();

    $self->cv->begin; # match in shutdown()
    scope_guard {
        $self->_running(0);
        try { $self->cleanup } catch { warn "during $NAME cleanup: $_" };
    };
    $self->cv->recv;
}

sub cleanup {
    my $self = shift;
    $self->_destroy_guards;
    # do this after so we don't conflict with EV
    $SIG{$_} = 'IGNORE' for qw(TERM INT QUIT);
    inner();
}

sub at_fork {
    my $self = shift;
    $self->_destroy_guards;
    $self->_running(0); # don't run in forked kid.
    inner();
}

sub shutdown {
    my $self = shift;
    return if $self->guards->{shutdown_timer};
    $self->_running(0);

    st_log()->info("$PROC_NAME shutting down");

    $self->disable_guard('server'); # don't accept new requests, shut down port

    inner();

    $self->guards->{shutdown_timer} = AE::timer $self->shutdown_delay,0,
        exception_wrapper {
            $self->cv->croak("timeout during shutdown");
        } "Shutdown timer error";

    $self->cv->end; # match in run()
}

sub stats_ticker {
    my $self = shift;

    my $stats = $self->stats;

    my $rpt = Socialtext::Timer->ExtendedReport();
    delete $rpt->{overall};
    my $active = $stats->{"current connections"};

    $self->stats({"current connections" => $active});
    Socialtext::Timer->Reset();

    my $ucname = uc($NAME);
    st_log->info("$ucname,STATUS,ACTOR_ID:0,".encode_json($stats));
    st_timed_log('info',$ucname,'TIMERS',0,{},undef,$rpt);
}

sub _wrap_request {
    my ($self, $handle, $env, $body_ref, $fatal, $err) = @_;

    if ($err) {
        trace "HTTPD error: $err";
        return;
    }

    my $req = $self->RequestClass->new(
        _handle => $handle, env => $env, body => $body_ref
    );

    try {
        $self->handle_request($req);
    }
    catch {
        my $e = 'handle_request: '.$_;
        st_log->error($e);
        trace($e);
        $req->simple_response('500 Server Error',
            "An error occurred when processing the $NAME request.")
            unless ($req->responding or !$req->alive);
    };
    return;
}

sub handle_request {
    my ($self,$req) = @_;
    die "WebDaemon subclass didn't override handle_request";
}

1;
__END__

=head1 NAME

Socialtext::WebDaemon - abstract base-class.

=head1 SYNOPSIS

    package 'My::Daemon';
    use Moose;
    BEGIN { extends 'Socialtext::WebDaemon' }
    use Socialtext::WebDaemon::Util;

    use constant Name => 'myd';
    use constant ProcName => 'st-myd';
    use constant 'RequestClass' => 'Socialtext::My::Request';

=head1 DESCRIPTION

Abstract base-class and factory for a number of socialtext "web daemons".

The RequestClass should sub-class L<Socialtext::WebDaemon::Request>

=cut
