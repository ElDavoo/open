#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 4;
use Socialtext::AppConfig;

fixtures(qw( base_config ));

###############################################################################
# TEST: soft limit sets properly
soft_limit_sets_properly: {
    my $expected = 12345;
    Socialtext::AppConfig->set(auth_token_soft_limit => $expected);
    my $received = Socialtext::AppConfig->auth_token_soft_limit;
    is $received, $expected, 'Auth Token soft limit sets properly';
}

###############################################################################
# TEST: hard limit sets properly
hard_limit_sets_properly: {
    my $expected = 23456;
    Socialtext::AppConfig->set(auth_token_hard_limit => $expected);
    my $received = Socialtext::AppConfig->auth_token_hard_limit;
    is $received, $expected, 'Auth Token hard limit sets properly';
}

###############################################################################
# TEST: soft limit of "0" means "a really long time"
soft_limit_zero_means_long_time_from_now: {
    Socialtext::AppConfig->set(auth_token_soft_limit => 0);
    my $received = Socialtext::AppConfig->auth_token_soft_limit;
    my $expected = 86400 * 365;
    is $received, $expected, "'Soft limit == 0' means 'long time from now'";
}

###############################################################################
# TEST: hard limit of "0" means "a really long time"
hard_limit_zero_means_long_time_from_now: {
    Socialtext::AppConfig->set(auth_token_hard_limit => 0);
    my $received = Socialtext::AppConfig->auth_token_hard_limit;
    my $expected = 86400 * 365;
    is $received, $expected, "'Hard limit == 0' means 'long time from now'";
}
