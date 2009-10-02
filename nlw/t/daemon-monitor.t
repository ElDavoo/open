#!perl
# @COPYRIGHT@
use warnings;
use strict;
use Test::More tests => 36;
use File::Temp qw/tempfile/;

ok -x 'bin/st-daemon-monitor', "it's executable";

END {
    # try to clean things up before we go
    diag "pkill st-daemon-monitor";
    system("pkill -9 st-daemon-monitor");
    diag "pkill cranky.pl";
    system("pkill -9 cranky.pl");
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
    for (1..5) {
        return if (waitpid($pid,1) == $pid); # non-blocking
        kill 9, -$pid;
        sleep 1;
    }
    die "failed to reap $pid";
}

sub test_monitor ($$;$) {
    my $cranky = shift;
    my $mon_args = shift;
    my $process_lives = shift || undef;

    unlink 't/tmp/mon';
    pass "begin ($cranky; $mon_args)";
    my ($fh,$pidfile) = tempfile();

    my $cranky_pid = fork_and_exec($cranky);
    print $fh $cranky_pid;
    close $fh;

    if ($cranky =~ m#^/bin/true#) {
        reap($cranky_pid);
    }
    else {
        sleep 1;
    }

    my $rc = system("bin/st-daemon-monitor ".$mon_args.
            qq{ --pidfile $pidfile --init "/bin/touch t/tmp/mon"});
    my $exit = $rc >> 8;
    if ($process_lives) {
        is $exit, 0, "didn't kill the daemon";
        ok !-f 't/tmp/mon', "didn't run the init cmd";
    }
    else {
        is $exit, 1, "killed the daemon";
        ok -f 't/tmp/mon', "ran the init cmd";
    }

    for (1..5) {
        last if waitpid($cranky_pid,1)==$cranky_pid; # non-blocking
        kill 9, -$cranky_pid;
        last if waitpid($cranky_pid,1)==$cranky_pid; # non-blocking
        sleep 1;
    }
    pass "done ($cranky; $mon_args)";
}

test_monitor('/bin/sleep 5','' => 'lives');
test_monitor('/bin/sleep 5','--rss 32 --vsz 32 --fds 10' => 'lives');

test_monitor('/bin/true',''); # special case: harness will reap

test_monitor('dev-bin/cranky.pl --ram 64',         '--rss 64');
test_monitor('dev-bin/cranky.pl --ram 64',         '--vsz 128');
test_monitor('dev-bin/cranky.pl --ram 64 --fds 64','--vsz 256 --fds 32');
test_monitor('dev-bin/cranky.pl --fds 64',         '--vsz 256 --fds 32');

