package Test::Socialtext::Async;
# @COPYRIGHT@
use warnings;
use strict;
use AnyEvent;
use AnyEvent::HTTP;
use Test::More;
use Time::HiRes qw/sleep/;
use Socialtext::JSON qw/decode_json/;

use base 'Exporter';
our @EXPORT = qw(wait_until_pingable);

sub wait_until_pingable {
    my $port = shift;
    my $kind = shift || 'proxy';

    my $ping_err = '?';
    my $started = AnyEvent->time;
    my $content;
    while (AnyEvent->now - $started < 30.0) {
        my $cv = AE::cv;
        my $t = AE::timer 5, 0, sub { $ping_err = 'timeout'; $cv->send(0) };
        my $r = http_request 'GET' => "http://localhost:$port/ping",
            timeout => 1,
            sub {
                my ($body,$hdr) = @_;
                if ($hdr->{Status} == 200) {
                    undef $ping_err;
                    $content = $body;
                    $cv->send(1);
                }
                else {
                    $ping_err = $hdr->{Reason};
                    $cv->send(0);
                }
            };
        last if $cv->recv;

        undef $t;
        undef $r;
        diag "waiting for $kind...";
        sleep 0.25;
    }
    die "server didn't respond to a ping after 30 seconds" if $ping_err;
    pass "$kind has started (".(AnyEvent->now - $started)." seconds)";

    $content =~ s/^.+?{/{/; # remove unparsable cruft
    my $got = decode_json($content);
    if ($kind eq 'proxy') {
        is_deeply $got, {
            "/ping" => { rc => 200, body => "pong" },
        }, "got correctly formatted response";
    }
    else {
        is $got->{ping}, 'ok', "ping response says 'ok'";
    }
}

1;
__END__

=head1 NAME

Test::Socialtext::Async - Test utils for async stuff

=head1 SYNOPSIS

  use Test::Socialtext::Async;
  wait_until_pingable($port, 'proxy');

=head1 DESCRIPTION

Various testing utilities for async apps.

=cut
