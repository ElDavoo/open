#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 6;
use Socialtext::UserGroupRoleFactory;

###############################################################################
# Fixtures: db
# - need a DB, but don't care what's in it.
fixtures(qw/db/);

use_ok 'Socialtext::User';

################################################################################
# NOTE: this behaviour is more extensively tested in
# t/Socialtext/UserGroupRoleFactory.t
################################################################################

################################################################################
# TEST: User is in no groups
user_has_no_groups: {
    my $me = create_test_user();
    my $groups = $me->groups;

    isa_ok $groups, 'Socialtext::MultiCursor', 'got a list of groups';
    is $groups->count(), 0, '... with the correct count';
}

################################################################################
# TEST: User is in groups
user_has_groups: {
    my $me        = create_test_user();
    my $group_one = create_test_group();
    my $group_two = create_test_group();

    $group_one->add_user(user => $me);
    $group_two->add_user(user => $me);

    my $groups = $me->groups();
    isa_ok $groups, 'Socialtext::MultiCursor', 'got a list of groups';
    is $groups->count(), 2, '... with the correct count';
    isa_ok $groups->next(), 'Socialtext::Group', '...';
}
