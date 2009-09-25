#!/usr/bin/env perl
# @COPYRIGHT@
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
use JSON::XS qw/encode_json decode_json/;
use Data::Dumper;
use URI::Escape qw/uri_escape_utf8/;
use List::Util qw/sum/;
use Coro::Debug;

my $UNPARSEABLE_CRUFT = "throw 1; < don't be evil' >";

#my $SERVER_ROOT = 'http://topaz.socialtext.net:22061';
my $SERVER_ROOT = 'http://dev7.socialtext.net';
my $REFRESH = 60;

$AnyEvent::HTTP::MAX_PER_HOST = $AnyEvent::HTTP::MAX_PERSISTENT_PER_HOST = 9999;

my $all_done = AE::cv;
our $phase_display = sub {print "nothing to report\n"};
my $ticker = AE::timer 2,2, unblock_sub {
    print "-" x 30,AnyEvent->now," ",$AnyEvent::HTTP::ACTIVE,"\n";
    $phase_display->();
    #Coro::Debug::command('ps');
};

# my %users = (
#     'devnull1@socialtext.com' => 'd3vnu11l',
#     'devnull2@socialtext.com' => 'd3vnu11l',
# #     'chester@socialtext.com' => 'd3vnu11l',
# #     'tester@socialtext.com' => 'd3vnu11l',
#     'q@q.q' => 'qwerty',
# );
my %users;
for my $n (1..100) {
    $users{"user-$n-48295\@ken.socialtext.net"} = 'password';
}
my %user_state;

sub run_for_user ($$&) {
    my $user = shift;
    my $desc = shift;
    my $code = shift;

    async {
        $Coro::current->{desc} = $desc;
#         Coro::on_enter {
#             %AnyEvent::HTTP::CO_SLOT  = %{$user_state{$user}{CO_SLOT}};
#             %AnyEvent::HTTP::KA_COUNT = %{$user_state{$user}{KA_COUNT}};
#         };
#         Coro::on_leave {
#             %{$user_state{$user}{CO_SLOT}}  = %AnyEvent::HTTP::CO_SLOT;
#             %{$user_state{$user}{KA_COUNT}} = %AnyEvent::HTTP::KA_COUNT;
#         };
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
                warn "Failed to log in $user ($headers->{Status})\n";
                $phase->croak('failed to log in '.$user);
            }
        };
    }
    $phase->recv;
    print "done logging in\n";
}

sub simple_fetch_events {
    my $phase = AE::cv;
    my $phase_timeout = AE::timer 3600, 0, sub {
        $all_done->send;
        $phase->croak('timed-out fetching stuff');
    };

    my %in_progress;
    my %plan;
    my $failed = 0;
    my $timeout = 0;
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

            my $last_event = '';
            my $last_signal = '';

            $plan{$user} = 10;
            $in_progress{$user} = {};
            Coro::AnyEvent::sleep rand($REFRESH); # fuzz offsets

            for (1..5) {
                my $fetches = AE::cv;
                my @fetch_guards;
                my $events_uri = '/data/events?limit=6;accept=application/json';
                $events_uri .= ";after=$last_event" if $last_event;
                my $signals_uri = '/data/signals?limit=6;accept=application/json';
                $signals_uri .= ";after=$last_signal" if $last_signal;

                for my $uri ( $events_uri, $signals_uri ) {
                    $fetches->begin;
                    my $req_url = $SERVER_ROOT.$uri;
                    my $url = "$SERVER_ROOT/nlw/proxy.scgi?url=" .
                        uri_escape_utf8($req_url).
                        '&httpMethod=GET&postData=&contentType=JSON'.
                        '&refresh='.$REFRESH;
                    my $cb = sub { 
                        my ($body, $headers) = @_;
#                         print "finish $user $uri $headers->{Status}\n";
                        $failed++ unless $headers->{Status} =~ /^200/;
                        $timeout++ if $headers->{Status} =~ /time/i;
                        delete $in_progress{$user}{$url};
                        eval {
                            $body =~ s/^\Q$UNPARSEABLE_CRUFT\E//;
                            my $wrapper = decode_json($body);
                            my $data = decode_json($wrapper->{$req_url}{body});
                            if ($data && $data->[0]) {
                                if ($wrapper->{$req_url} =~ m#/data/events#) {
                                    $last_event = $data->[0]{at};
#                                     warn "event at: $last_event\n";
                                }
                                else {
                                    $last_signal = $data->[0]{at};
#                                     warn "signal at: $last_signal\n";
                                }
                            }
                        };
                        warn $@ if $@;
                        $fetches->end;
                    };
                    my $fg = http_get $url,
                        recurse => 0,
                        timeout => 120,
                        headers => {
                            'Cookie' => $user_state{$user}{cookie}
                        },
                        $cb;
                    $in_progress{$user}{$url} = $fg;
                    $plan{$user}--;
#                     print "sent $user\n";
                }
                $fetches->recv;
#                 print "pausing $user";
                Coro::AnyEvent::sleep 30 if $plan{$user}; # simulate polling
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
    eval { 
        log_in_users();
        simple_fetch_events();
    };
    if ($@) {
        warn "death! $@\n";
    }
    $all_done->send;
}

my $main_start = AnyEvent->time;
print "main: waiting...\n";
$all_done->recv;
my $main_elapsed = AnyEvent->time - $main_start;
print "done in $main_elapsed seconds\n";
