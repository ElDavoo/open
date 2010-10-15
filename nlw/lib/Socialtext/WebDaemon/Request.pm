package Socialtext::WebDaemon::Request;
# @COPYRIGHT@
use Moose;
use MooseX::StrictConstructor;
use Encode qw/is_utf8 encode_utf8/;
use Socialtext::Async::HTTPD qw/serialize_response/;
use Socialtext::WebDaemon::Util; # auto-exports
use namespace::clean -except => 'meta';

has 'env' => (is => 'ro', isa => 'HashRef', required => 1);
has 'query' => (is => 'rw', isa => 'HashRef', lazy_build => 1);
has 'body' => (is => 'ro', isa => 'Maybe[ScalarRef]', required => 1);
has 'for_user_id' => (is => 'rw', isa => 'Int', default => 0);

has 'log_params' => (is => 'rw', isa => 'HashRef', default => sub {{}});
has 'started_at' => (is => 'rw', isa => 'Num');
has '_pid' => (is => 'rw', isa => 'Int');

has '_r' => (is => 'ro', isa => 'Feersum::Connection', required => 1,
    clearer => '_clear_r', predicate => 'alive');
has 'ident' => (is => 'rw', isa => 'Str', default => '??', writer => '_ident');
has 'responding' => (is => 'ro', isa => 'Bool', writer => '_responding');

sub BUILD {
    my $self = shift;
    weaken $self;

    $self->_ident("fd=".$self->_r->fileno().
        ', user_id='.$self->for_user_id);

    DAEMON()->stats->{"current connections"}++;
    $self->_r->response_guard(guard {
        trace "=> DROP ".$self->ident."\n";
        DAEMON()->stats->{"current connections"}--;
    });

    $self->started_at(AE::now);
    my $env = $self->env;
    $self->_pid($$); # for detecting forks
    trace "=> REQUEST ".$self->ident.": ".
        "$env->{REQUEST_METHOD} $env->{PATH_INFO} $env->{QUERY_STRING}\n";
}

sub _build_query {
    my $self = shift;
    my $qstr = $self->env->{QUERY_STRING} || '';
    my @qp = split /[;&=]/, $qstr;
    return { nowait => 0, client_id => '', @qp }
        if (@qp % 2 == 0);
    return {};
}

sub log_start {
    my $self = shift;
    st_log->debug(join(',',
        uc(NAME()),'START_'.$self->env->{REQUEST_METHOD},
        uc($self->env->{PATH_INFO}),
        "ACTOR_ID:".$self->for_user_id,
        encode_json($self->log_params)
    ));
}

sub log_done {
    my ($self,$code) = @_;
    $self->log_params->{timers} = 'overall(1):'.
        sprintf('%0.3f', AE::now - $self->started_at);
    st_log->info(join(',',
        'WEB',$self->env->{REQUEST_METHOD},
        uc($self->env->{PATH_INFO}),
        $code,
        "ACTOR_ID:".$self->for_user_id,
        encode_json($self->log_params)
    ));
}

sub simple_response {
    my ($self, $message, $content_or_ref, $ct) = @_;

    $ct ||= 'text/plain; charset=UTF-8';
    $ct = 'application/json; charset=UTF-8' if $ct eq 'JSON';
    my $ref = ref($content_or_ref) ? $content_or_ref : \$content_or_ref;
    $ref = \encode_utf8($$ref) if is_utf8($$ref);
    $self->respond($message, ['Content-Type' => $ct], $ref);
    return;
}

sub respond {
    my ($self, $message, $hdrs, $content, $cb) = @_;

    unless ($self->alive && !$self->responding) {
        confess "attempted to respond twice to a request";
        return;
    }
    my $r = $self->_r;
    $self->_clear_r;

    no warnings 'numeric';
    my $code = 0 + $message;

    # replace the default guard so we can log a completion message (strong
    # reference is OK).
    $r->response_guard->cancel;
    $r->response_guard(guard {
        $self->log_done($code);
        $cb->() if $cb;
        DAEMON()->stats->{"current connections"}--;
        undef $self; # important reference closure.
    });

    $r->send_response($message, $hdrs, $content);
    $self->_responding(1);
    trace "<= RESPONSE ".$self->ident.": ".$message.$/;

    return;
}

# Later:
# sub start_response { my ($code,$headers) = @_; }
# sub write { $_[0] }
# sub end_response { }

__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

Socialtext::Handler::Push::Request - pushd request object

=head1 SYNOPSIS

  http_server $host, $port, sub {
      my ($handle, $env, $body_ref) = @_; # among others
      my $req = Socialtext::Handler::Push->new(
          handle => $handle, env => $env, body => $body_ref);

      # pass around $req, then

      my $resp = HTTP::Response->new(...);
      $req->respond($resp, sub {
          # called when done writing to the handle,
          # clean things up, e.g.:
          undef $handle;
          undef $req;
      });
  };

=head1 DESCRIPTION

Abstracts the AnyEvent::Handle used under Socialtext::Async::HTTPD.  One of
these objects per active Client in C<st-pushd>.

=cut
