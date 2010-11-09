#!/usr/bin/perl
package Foo;    # so we can use the Async::Wrapper here in the test
use strict;
use warnings;
use Test::Socialtext tests => 5;
use Moose;
use File::Temp qw(tempfile);
use Socialtext::Async::Wrapper;

fixtures(qw( base_layout ));

sub check_log ($);

###############################################################################
# Make our child worker processes log STDERR, so we can pick it up later.
my ($fh,$filename) = tempfile;
Socialtext::Async::Wrapper->RegisterAtFork(sub {
    open STDERR, '>>&', $fh;
    select STDERR; $|=1; select STDOUT;
});

###############################################################################
# Create a series of worker functions/methods to test
worker_function short_time => sub {
    return "yes!";
};

worker_function take_a_long_time => sub {
    sleep 2;
};

worker_wrap wrapper_method => 'Foo::existing_method';
sub wrapper_method {
    call_orig_in_worker(wrapper_method => @_);
}
sub existing_method {
    sleep 2;
}

###############################################################################
# TEST: short running workers do *not* get logged
do_not_log_short_running: {
    call_orig_in_worker(short_time => 'Foo', 7,8,9);
    check_log(0);
}

###############################################################################
# TEST: long running worker functions get logged
log_long_running_function: {
    call_orig_in_worker(take_a_long_time => 'Foo', 1, 2, 3);
    check_log qr/long running worker \\'worker_take_a_long_time\\'/;
}

###############################################################################
# TEST: long running worker methods get logged
log_long_running_method: {
    Foo->existing_method(4,5,6);
    check_log qr/long running worker \\'worker_wrapper_method\\'/;
}






###############################################################################
# Check the log from a child worker, for a matching line.
sub check_log ($) {
    my $look_for = shift;
    sleep 1;
    seek $fh, 0, 0;
    my @lines = <$fh>;
    truncate $fh, 0;

    unless ($look_for) {
        is scalar(@lines), 0, 'nothing logged' or diag @lines;
    }
    else {
        like $lines[0], $look_for, 'found our log line';
        is scalar(@lines), 1, 'only a single line' or diag @lines;
    }
}
