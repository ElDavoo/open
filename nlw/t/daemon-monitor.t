#!perl
# @COPYRIGHT@
use warnings;
use strict;
use Test::More tests => 86;
use File::Temp qw/tempfile/;
use Time::HiRes ();

ok -x 'bin/st-daemon-monitor', "it's executable";

END {
    local $?; # don't clobber it via system()
    # try to clean things up before we go
    diag "cleanup: killall -9 st-daemon-monitor";
    system("killall -9 st-daemon-monitor");
    diag "cleanup: killall -9 cranky.pl";
    system("killall -9 cranky.pl");
    unlink 't/tmp/mon';
}

our $init_cmd = '"/bin/touch t/tmp/mon"';

sub fork_and_exec {
    my @cmd = @_;
    my $pid = fork();
    if ($pid || !defined($pid)) {
        ok $pid, "forked @cmd";
        return $pid;
    }
    exec(@cmd) or die "can't exec: $!";
}

sub reap {
    my $pid = shift;
    for (1..50) {
        return if (waitpid($pid,1) == $pid); # non-blocking
        kill 9, $pid;
        kill 9, -$pid;
        return if (waitpid($pid,1) == $pid); # non-blocking
        #diag("waiting for child process...");
        Time::HiRes::sleep(0.1);
    }
    die "failed to reap $pid";
}

my $last_log;

sub test_monitor ($$;$) {
    my $cranky = shift;
    my $mon_args = shift;
    my $process_lives = shift || undef;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    unlink 't/tmp/mon';
    pass "begin ($cranky; $mon_args)";
    my ($fh,$pidfile) = tempfile();

    my $cranky_pid = fork_and_exec($cranky);
    print $fh $cranky_pid;
    close $fh;

    my $reaped = 0;
    if ($cranky =~ m#^/bin/true#) {
        reap($cranky_pid);
        $reaped = 1;
    }
    elsif ($cranky =~ m#^/bin/false#) {
        reap($cranky_pid);
        unlink $pidfile;
        $reaped = 1;
    }
    else {
        sleep 1;
    }

    system("/bin/bash","-c",":> t/tmp/log/nlw.log");

    my $rc = system(
        "bin/st-daemon-monitor ".$mon_args.
        qq{ --pidfile $pidfile --init "/bin/touch t/tmp/mon"}
    );
    my $exit = $rc >> 8;

    if ($process_lives) {
        is $exit, 0, "didn't kill the daemon";
        ok !-f 't/tmp/mon', "didn't run the init cmd";
    }
    else {
        is $exit, 1, "killed the daemon";
        ok -f 't/tmp/mon', "ran the init cmd";
    }

    if (!$reaped) {
        reap($cranky_pid);
    }
    pass "done ($cranky; $mon_args)";

    $last_log = '';
    eval {
        local $/;
        open my $logfh, '<', 't/tmp/log/nlw.log';
        ($last_log) = <$logfh>;
        close $logfh;
    };
}

sub logged_like ($) {
    my $re = shift;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    like $last_log, qr/$re/m, 'logged correctly';
}

my $c = 'dev-bin/cranky.pl ';

test_monitor('/bin/sleep 5', ''                           => 'lives');
test_monitor('/bin/sleep 5', '--rss 32 --vsz 32 --fds 10' => 'lives');

# special case: harness will reap
test_monitor('/bin/true','');
logged_like qr/is (gone|zombified)/;

# special case: harness will reap, remove pidfile
test_monitor('/bin/false','');
logged_like qr/can't read pidfile/;

test_monitor($c.'--ram 64',         '--rss 64');
logged_like qr/is too big \(RSS\)/i;
test_monitor($c.'--ram 64',         '--vsz 256' => 'lives');
test_monitor($c.'--ram 64',         '--vsz 64');
logged_like qr/is too big \(vsize\)/i;
test_monitor($c.'--ram 64 --fds 64','--vsz 256 --fds 32');
logged_like qr/has too many files open/i;
test_monitor($c.'--fds 64',         '--vsz 256 --fds 32');
logged_like qr/has too many files open/i;

socket_tests: {
    # check for open port only; monitor doesn't try to connect
    my $port = $>+26000;

    test_monitor($c.'--after 5 --serv none', ''            => 'lives');
    test_monitor($c.'--after 5 --serv none', "--tcp $port"           );
    logged_like qr/tcp port $port is not open/i;
    test_monitor($c.'--after 5',             "--tcp $port" => 'lives');

    # cranky should give a 403
    test_monitor(
        $c.'--serv scgi',
        "--scgi --tcp $port"
    );
    logged_like qr/non-200/;

    # cranky gives a 200
    test_monitor(
        $c.'--after 5 --serv scgi --scgi ok',
        "--scgi --tcp $port"
        => 'lives'
    );

    # socket timeout. Do this last since it's slow.
    test_monitor(
        $c.'--serv stall',
        "--scgi --tcp $port"
    );
    logged_like qr/timeout/;
}

pass "all done";
