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
use List::Util qw/sum/;

my $SERVER_ROOT = 'http://topaz.socialtext.net:22061';

my $all_done = AE::cv;
our $phase_display = sub {print "nothing to report\n"};
my $ticker = AE::timer 2,2, unblock_sub {
    print "-" x 30,AnyEvent->now,"\n";
    $phase_display->();
};

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
    my $phase = AE::cv;
    my $phase_timeout = AE::timer 60, 0, sub {
        $all_done->send;
        $phase->croak('timed-out logging-in users');
    };
    print "logging-in users...\n";

    my %guards; # cancelling guards
    local $phase_display = sub {
        print "logging in users, ".(scalar keys %guards)." remaining\n";
    };

    for my $user (keys %users) {
        $phase->begin;

        $user_state{$user} = {
            name => $user,
            CO_SLOT => {},
            KA_COUNT => {},
        };

        run_for_user $user, "log-in $user", sub {
            scope_guard { $phase->end if $phase };
#             print "logging in $user\n";
            my $password = $users{$user} || 'password';
            my $post = "redirect_to=/&lite=&remember=1&".
                "username=".uri_escape_utf8($user).
                "&password=".uri_escape_utf8($password);
#             warn "post: $post\n";

            my $g2 = http_post "$SERVER_ROOT/nlw/submit/login", $post,
                headers => { 
                    'Content-Type' => 'application/x-www-form-urlencoded',
                    'Content-Length' => length($post),
                },
                timeout => 10,
                Coro::rouse_cb;
            $guards{$user} = $g2;

#             print "waiting for $user\n";
            my (undef, $headers) = Coro::rouse_wait;
            delete $guards{$user};

            my $c = $headers->{'set-cookie'};
            if ($c && $c =~ /(NLW-user=[^;]+)/) {
                $user_state{$user}{cookie} = $1;
#                 print "logged-in: $user ($user_state{$user}{cookie})\n";
            }
            else {
                warn "Failed to log in $user\n";
                $phase->croak('failed to log in '.$user);
            }
        };
    }
    $phase->recv;
    print "done logging in\n";
}

sub simple_fetch_events {
    my $phase = AE::cv;
    my $phase_timeout = AE::timer 60, 0, sub {
        $all_done->send;
        $phase->croak('timed-out fetching stuff');
    };

    my %in_progress;
    my %plan;
    my $failed = 0;
    local $phase_display = sub {
        my $total_u = scalar keys %in_progress;
        my $outstanding = sum values %plan;
        print "fetching, remaining: $total_u users, ".
            "$outstanding requests. ($failed failed)\n";
    };

    for my $user (keys %users) {
        $phase->begin;
        run_for_user $user, "fetcher for $user", sub {
            scope_guard { $phase->end if $phase };
            Coro::AnyEvent::sleep rand(2.5); # fuzz offsets
            $plan{$user} = 10;
            for (1..5) {
                my $fetches = AE::cv;
                my @fetch_guards;
                for my $uri (
                    '/data/events?limit=5;accept=application/json',
                    '/data/signals?limit=5;accept=application/json',
                ) {
                    $fetches->begin;
                    my $url = "$SERVER_ROOT/nlw/proxy.scgi?url=" .
                        uri_escape_utf8("$SERVER_ROOT$uri") .
                        '&requestMethod=GET';
                    my $fg = http_get $url,
                        recurse => 0,
                        timeout => 30,
                        headers => {
                            'Cookie' => $user_state{$user}{cookie}
                        },
                        sub { 
                            my ($body, $headers) = @_;
#                             print "finish $user $headers->{Status}\n";
                            $failed++ unless $headers->{Status} =~ /^200/;
                            delete $in_progress{$user}{$url};
                            eval {
                                my $wrapper = decode_json($body);
                                my $data = decode_json($wrapper->{body});
                                print "at: ".$data->[0]{at};
                            };
                            $fetches->end;
                        };
                    $in_progress{$user}{$url} = $fg;
                    $plan{$user}--;
#                     print "sent $user\n";
                }
                $fetches->recv;
#                 print "pausing $user";
                Coro::AnyEvent::sleep 5 if $plan{$user}; # simulate polling
            }
#             print "+ phase done for $user\n";
            delete $in_progress{$user};
        };
    }
    $phase->recv;
#     print "++ phase all done\n";
    $phase_display->();
}

async { $Coro::current->{desc} = 'main schedule';
    log_in_users();
    simple_fetch_events();
    $all_done->send;
}

print "main: waiting...\n";
$all_done->recv;
print "done\n";
