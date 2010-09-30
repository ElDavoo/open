package Socialtext::Handler::Userd;
# @COPYRIGHT@
use Moose;
use MooseX::AttributeHelpers;
use MooseX::StrictConstructor;

use Socialtext::Async;
use Socialtext::Async::HTTPD qw/http_server/;
use Socialtext::Async::WorkQueue;
use Socialtext::Async::Wrapper;
use Socialtext::Log qw/st_log st_timed_log/;
use Socialtext::SQL qw/get_dbh sql_execute sql_singlevalue/;
use Socialtext::JSON qw/decode_json encode_json/;
use Socialtext::UserSet ':const';
use Socialtext::Timer qw/time_scope/;
use Socialtext::HTTP::Cookie;
use Socialtext::Cache;
use Socialtext::IntSet;

use Socialtext::AppConfig;
use Socialtext::User;
use Socialtext::User::Cache;
use Socialtext::User::Default::Factory;

BEGIN {
    # {bz: 4151} - load LDAP code in the parent if that factory is enabled.
    if (Socialtext::AppConfig->user_factories  =~ /LDAP/ ||
        Socialtext::AppConfig->group_factories =~ /LDAP/)
    {
        require Socialtext::User::LDAP::Factory;
        require Socialtext::Group::LDAP::Factory;
    }

    # This is for {bz: 4083}: We cache the GetProfile results for
    # rendering Signals for as long as possible; the cache is expired
    # on a per-user basis via /data/push/update {"update":"profile"}.
    $Socialtext::Cache::DefaultExpiresIn = 'never';
}

use Guard;

# TODO: this is a generic module and needs a rename and deal with HANDLER
# properly.
use Socialtext::Handler::Push::Util;

use namespace::clean -except => 'meta';


has 'host' => (is => 'rw', isa => 'Str', default => '127.0.0.1');
has 'port' => (is => 'rw', isa => 'Int', default => 8084);

has 'is_running' => (
    is => 'rw', isa => 'Bool',
    default => 1, writer => '_running'
);

has 'cv' => (
    is => 'ro', isa => 'AnyEvent::CondVar',
    lazy => 1,
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

has extract_q => (
    is => 'ro', isa => 'Socialtext::Async::WorkQueue',
    lazy_build => 1
);

our $SINGLETON;

sub run {
    my $self = shift;
    Scalar::Util::weaken $self;

    st_log()->info("userd starting on ".$self->host." port ".$self->port);

    worker_make_immutable();

    $self->guards->{server} = http_server $self->host, $self->port,
        unblock_sub { $self->handle_request(@_) };
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

    $self->cv->begin; # match in shutdown()
    my $e;
    try { $self->cv->recv } catch { $e = $_ };
    warn $e if $e;
    $self->_running(0);
    try { $self->_cleanup } catch { warn "during userd cleanup: $_" };
    die $e if $e;
}

sub _cleanup {
    my $self = shift;
    $self->_destroy_guards;
    # do this after so we don't conflict with EV
    $SIG{$_} = 'IGNORE' for qw(TERM INT QUIT);
}

sub at_fork {
    my $self = shift;
    $self->_destroy_guards;
    $self->extract_q->drop_pending();
    $self->extract_q->shutdown_nowait();
    $self->_running(0); # don't run in forked kid.
}

sub shutdown {
    my $self = shift;
    return if $self->guards->{shutdown_timer};
    $self->_running(0);

    st_log()->info("userd shutting down");

    $self->disable_guard('server'); # TODO: put this in pushd too?

    if ($self->has_extract_q) {
        $self->extract_q->shutdown_nowait();
    }

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

    st_log->info("USERD,STATUS,ACTOR_ID:0,".encode_json($stats));
    st_timed_log('info','USERD','TIMERS',0,{},undef,$rpt);
}


my $CRLF = "\015\012";
sub handle_request {
    my ($self, $h, $env, $body_ref, $fatal, $err) = @_;

    if ($err) {
        trace "HTTPD error: $err";
        return;
    }

    $self->cv->begin;

    my $path = $env->{PATH_INFO};
    my $responder = sub {
        # flush written data.
        $h->push_write($_[0]);
        $h->on_drain(sub {
            $h->{fh}->close();
            $h->destroy;
            $self->cv->end; # for controlling graceful shutdown
            # keep a reference to the handle until all data has been flushed out
            undef $h;
        });
        st_log->info("USERD,GET,$path");
    };
    
    if ($path eq '/ping') {
        $responder->(
            "HTTP/1.0 200 OK$CRLF".
            "Content-Type: application/json; charset=UTF-8$CRLF".
            "Connection: close$CRLF".
            $CRLF.
            qq({"ping":"ok"})
        );
    }
    elsif ($path eq '/stuserd') {
        my $params = decode_json($$body_ref);
        # If we've got cached results, use those right away
        # ... *DON'T* block here; this has to be wikkid fast
        # Otherwise, enqueue a worker to extract the results and add it to my
        # cache.
        $self->extract_q->enqueue( [$params, $responder] );
    }
    else {
        $responder->(
            "HTTP/1.0 400 Bad Request$CRLF".
            "Content-Type: text/plain$CRLF".
            "Connection: close$CRLF".
            $CRLF.
            qq(Your browser sent a request the server did not understand\n)
        );
    }

    return;
}

sub _build_extract_q {
    my $self = shift;
    weaken $self;
    my $wq; $wq = Socialtext::Async::WorkQueue->new(
        name => 'extract',
        prio => Coro::PRIO_LOW(),
        cb => exception_wrapper(sub {
            my ($params,$responder) = @_;

            return unless $self;

            my $result = do_extract_creds($params);
            my $http = result_to_http($result);
            $responder->($http);
        }, 'extract queue error'),

        after_shutdown => sub {
            $self->cv->end if $self;
        }
    );
    $self->cv->begin;
    return $wq;
}

worker_function do_extract_creds => sub {
    my $params = shift;
    # this executes in a sub-process
};

1;
