#!/usr/bin/env perl
# @COPYRIGHT@
use warnings;
use strict;
use Test::Socialtext tests => 13;
use Test::Socialtext::Async;
use Socialtext::JSON qw/decode_json/;
use Socialtext::Paths;

BEGIN {
    POSIX::setsid();
}

use Socialtext::HTTP::Ports;

fixtures(qw(db));

my $logpath = Socialtext::Paths->log_directory();
my $nlw_log_file = "$logpath/nlw.log";

my $port = empty_port();
my $st_userd = "$ENV{ST_CURRENT}/nlw/bin/st-userd";
die "userd script is not executable" unless -x $st_userd;
diag "starting st-userd on port $port with script $st_userd";

my $pid = fork_off($st_userd, "--port", $port);

my $user = create_test_user();
my $user_id = $user->user_id;

wait_until_pingable($port, 'userd');
wait_until_pingable($port, 'userd');

use LWP::UserAgent;
use HTTP::Request;
for (1..2) {
    my $req = HTTP::Request->new('POST' => "http://localhost:$port/stuserd");
    $req->content_ref(\q({"hi":"there"}));
    my $ua = LWP::UserAgent->new;
    my $resp = $ua->request($req);
    is $resp->code(), 200, "simple POST gets 200";
}

kill_kill_pid($pid);

sleep 1; # let the log flush
my @log_lines = grep /\[$pid\]: \[$<\]/, `tail -n 25 $nlw_log_file`;
chomp @log_lines;

my @expect_lines = (
    qr#\Qst-userd is starting up#,
    qr#\Qst-userd starting on 127.0.0.1 port $port#,
    qr#\QWEB,GET,/PING,200,ACTOR_ID:0,{"timers":"overall(1):0.000"}#,
    qr#\Qst-userd shutting down#
);

good_logging: {
    for my $expect (@expect_lines) {
        my $found = '';
        INNER: for my $line (@log_lines) {
            if ($line =~ /nlw\[$pid\]: \[$<\] $expect/) {
                $found = $line;
                last INNER;
            }
        }
        like $found, $expect, "found expected log line";
    }
}

pass "done";
