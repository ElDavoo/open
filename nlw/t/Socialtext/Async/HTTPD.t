#!perl
use warnings;
use strict;

use Test::More tests => 6;
use AnyEvent;
use AnyEvent::Util qw/portable_socketpair/;
use AnyEvent::Handle;
use Socialtext::Async::HTTPD;

my ($client_fh,$server_fh) = portable_socketpair();
ok $client_fh && $server_fh, "got socketpair";

my $all_done = AE::cv;
my $nohang = AE::timer 10,0,sub {
    print "# test timeout!\n";
    exit 1;
};

my $CRLF = "\015\012";

my $client_t;
sub client {
    $all_done->begin;
    my $h = AnyEvent::Handle->new(fh => $client_fh);
    $h->on_error(sub { $all_done->croak("client error: ".$_[2]) });

    $h->push_write(
        "POST /foo?bar=baz HTTP/1.0$CRLF".
        "Host: blah$CRLF".
        "Content-Length: 4$CRLF".
        "Content-Type: text/plain$CRLF".
        $CRLF
    );

    $client_t = AE::timer(1,0,sub {
        pass "client: finishing request";
        $h->push_write("quxx");
    });

    $h->on_read(sub {
        pass "client: got a response";
        $all_done->end if $h->{rbuf} =~ /done!/;
    });

    return $h;
}

sub server {
    $all_done->begin;
    return Socialtext::Async::HTTPD::handle_http($server_fh, 'dummyhost','666',
        sub {
            my $handle = shift;
            my $env = shift;
            my $body = shift;
            my $is_fatal = shift;
            my $error = shift;

            is $error, undef, "server: no error";

            pass "server: got a request";

            $handle->push_write("done!");
            $handle->on_drain(sub {
                pass "server: finished response";
                $all_done->end;
                $handle->destroy;
            });
        });
}

my $client_h = client();
server();

$all_done->recv();
