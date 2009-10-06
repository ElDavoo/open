package Socialtext::SCGI;
# @COPYRIGHT@
use warnings;
use strict;

=head1 NAME

Socialtext::SCGI - Helper functions 

=head1 SYNOPSIS

  use AnyEvent;
  use Socialtext::SCGI;
  my ($err,$response) = Socialtext::SCGI->Ping(26061, 10);
  my $resp = HTTP::Message->parse($response);

=head1 DESCRIPTION

Utility methods for SCGI.

This module uses L<AnyEvent> to do non-blocking I/O.

=head1 METHODS

=cut

use AnyEvent;
use AnyEvent::Handle;
use Guard;

=head2 Ping $port[, $timeout]

Connect to the specified SCGI port and send a request for "GET /ping" with a
minimal "CGI" environment.

C<$timeout> defaults to 10 seconds.

=cut

sub Ping {
    my $class = shift;
    my $port = shift || die 'Need a port to ping';
    my $timeout = shift || 10;

    my $z = "\0";
    my $ping = "CONTENT_LENGTH${z}0${z}SCGI${z}1${z}". # headers
               "REQUEST_METHOD${z}GET${z}".
               "REQUEST_URI${z}/ping${z}";

    my $err;
    my $response = '';

    my $cv = AE::cv;
    my $t = AE::timer $timeout, 0, sub {$cv->croak('timeout timer')};

    #warn "connecting... ".time;
    my $h = AnyEvent::Handle->new(
        connect => ['localhost', $port],
        timeout => $timeout,
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
    );
    Guard::scope_guard(sub { $h->destroy });

    $h->push_write(netstring => $ping);
    $h->push_shutdown();

    # read the whole response, assuming "Connection: close"
    $h->on_read(sub { $response .= delete $h->{rbuf} });
    $h->on_eof(sub { $cv->send });

    eval { $cv->recv };
    $err = $@ || '';
    chomp $err;
    return ($err, $response);
}

1;
