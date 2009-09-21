#!/usr/bin/env perl
use warnings;
use strict;

use EV;
use Coro;
use AnyEvent;
use Coro::AnyEvent;
use AnyEvent::HTTP;
# use AnyEvent::AIO ();
# use Coro::AIO;
# use Coro::LWP;
use Coro::Channel;
use Guard;
use JSON::XS;
use Data::Dumper;
use URI::Escape qw/uri_escape_utf8/;

my $SERVER_ROOT = 'http://topaz.socialtext.net:22061';

my $all_done = AE::cv;
my $ticker = AE::timer 2,2,sub { print "tick\n" };

my %users = (
    'devnull1@socialtext.com' => 'd3vnu11l',
    'devnull2@socialtext.com' => 'd3vnu11l',
#     'chester@socialtext.com' => 'd3vnu11l',
#     'tester@socialtext.com' => 'd3vnu11l',
    'q@q.q' => 'qwerty',
);
my %user_state;

sub run_for_user ($$&) {
    my $user = shift;
    my $desc = shift;
    my $code = shift;

    async {
        $Coro::current->{desc} = $desc;
        Coro::on_enter {
            %AnyEvent::HTTP::CO_SLOT  = %{$user_state{$user}{CO_SLOT}};
            %AnyEvent::HTTP::KA_COUNT = %{$user_state{$user}{KA_COUNT}};
        };
        Coro::on_leave {
            %{$user_state{$user}{CO_SLOT}}  = %AnyEvent::HTTP::CO_SLOT;
            %{$user_state{$user}{KA_COUNT}} = %AnyEvent::HTTP::KA_COUNT;
        };
        $code->($user);
    };
}

sub log_in_users {
    my $logins = AE::cv;
    my $login_timeout = AE::timer 60, 0, sub {
        $all_done->send;
        $logins->croak('timed-out logging-in users');
    };
    print "logging-in users...\n";

    my @running; # cancelling guards
    for my $user (keys %users) {
        $logins->begin;

        $user_state{$user} = {
            name => $user,
            password => $users{$user},
            CO_SLOT => {},
            KA_COUNT => {},
            cookie_jar => {},
        };

        run_for_user $user, "log-in $user", sub {
            scope_guard { $logins->end if $logins };
            print "logging in $user\n";
            my $g2 = http_post "$SERVER_ROOT/nlw/submit/login",
                "username=$user&password=$users{$user}",
                cookie_jar => $user_state{$user}{cookie_jar},
                recurse => 0,
                timeout => 10,
                Coro::rouse_cb;
            push @running, $g2;
            print "waiting for $user\n";

            my (undef, $headers) = Coro::rouse_wait;
            if (my $c = $headers->{'set-cookie'}) {
                print "Got: $user\n";
            }
            else {
                print "Failed to log in $user\n";
                $logins->croak('failed to log in '.$user);
            }
        };
    }
    $logins->recv;
    print "done logging in\n";
}

sub simple_fetch_events {
    my $phase = AE::cv;
    my $phase_timeout = AE::timer 60, 0, sub {
        $all_done->send;
        $phase->croak('timed-out fetching stuff');
    };

    my @running; # cancelling guards
    for my $user (keys %users) {
        $phase->begin;
        run_for_user $user, "fetcher for $user", sub {
            scope_guard { $phase->end if $phase };

            for (1..5) {
                my $fetches = AE::cv;
                for my $uri (
                    '/data/events?limit=5;accept=application/json',
                    '/data/signals?limit=5;accept=application/json',
                ) {
                    $fetches->begin;
                    my $url = "$SERVER_ROOT/nlw/proxy.scgi?url=" .
                        uri_escape_utf8("$SERVER_ROOT$uri") .
                        '&requestMethod=GET';
                    my $fg = http_get $url,
                        cookie_jar => $user_state{$user}{cookie_jar},
                        sub { 
                            my (undef, $headers) = @_;
                            print "finish $user @ $headers->{URL}\n";
                            $fetches->end 
                        };
                    print "sent $user @ $url\n";
                    push @running, $fg;
                }
                $fetches->recv;
            }
            print "phase done for $user\n"
        };
    }
    $phase->recv;
    print "phase all done\n";
}

async { $Coro::current->{desc} = 'main schedule';
    log_in_users();
    simple_fetch_events();
    $all_done->send;
}

print "main: waiting...\n";
$all_done->recv;
print "done\n";
