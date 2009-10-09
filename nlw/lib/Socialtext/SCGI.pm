package Socialtext::SCGI;
use Moose;

# @COPYRIGHT@

=head1 NAME

Socialtext::SCGI - Helper functions 

=head1 SYNOPSIS

  use AnyEvent;
  use Socialtext::SCGI;
  my ($err,$response) = Socialtext::SCGI->Ping(26061, 10);
  my $resp = HTTP::Message->parse($response);

  my $client = Socialtext::SCGI->new(port => 26061);
  my ($err,$response) = $client->get("/ping");

=head1 DESCRIPTION

Utility methods for SCGI.

This module uses L<AnyEvent> to do non-blocking I/O.

=head1 METHODS

=cut

use AnyEvent;
use AnyEvent::Handle;
use Guard;
use namespace::clean -except => 'meta';

has 'port' => (is => 'ro', isa => 'Int', required => 1);
has 'timeout' => (is => 'ro', isa => 'Num', required => 1, default => 10.0);
has 'on_connect' => (is => 'ro', isa => 'CodeRef');

=head2 Socialtext::SCGI->Ping $port[, $timeout]

Connect to the specified SCGI port and send a request for "GET /ping" with a
minimal "CGI" environment.

C<$timeout> defaults to 10 seconds.

=cut

sub Ping {
    my $class = shift;
    my $port = shift || die 'Need a port to ping';
    my $timeout = shift || 10;
    my $self = $class->new(
        port => $port,
        timeout => $timeout,
    );
    return $self->get("/ping");
}

=head2 $self->get $uri

GET the specified URI.

=cut

sub get {
    my $self = shift;
    my $uri = shift;
    my $more_env = shift;

    my $z = "\0";
    my $nstr = "CONTENT_LENGTH${z}0${z}SCGI${z}1${z}". # headers
               "REQUEST_METHOD${z}GET${z}".
               "REQUEST_URI${z}${uri}${z}";
    if ($more_env) {
        while (my ($k,$v) = each(%$more_env)) {
            $nstr .= "$k$z$v$z";
        }
    }

    my $err;
    my $response = '';

    my $cv = AE::cv;
    my $t = AE::timer $self->timeout, 0, sub {$cv->croak('timeout timer')};

    #warn "connecting... ".time;
    my $h = AnyEvent::Handle->new(
        connect => ['localhost', $self->port],
        timeout => $self->timeout,
        on_timeout => sub {$cv->croak('timeout handle')},
        on_eof => sub { $cv->send },
        on_error => sub {
            my (undef, $fatal, $msg) = @_;
            if (length($response) && $msg =~ /^Broken pipe/i) {
                $cv->send; # presume we're done
            }
            else {
                #warn "croak error";
                $cv->croak($msg);
            }
        },
        on_connect => sub {$self->on_connect->() if $self->on_connect},
    );
    Guard::scope_guard(sub { $h->destroy });

    $h->push_write(netstring => $nstr);
    $h->push_shutdown();

    # read the whole response, assuming "Connection: close"
    $h->on_read(sub { $response .= delete $h->{rbuf} });
    $h->on_eof(sub { $cv->send });

    eval { $cv->recv };
    $err = $@ || '';
    chomp $err;
    return ($err, $response);
}

__PACKAGE__->meta->make_immutable;
1;
