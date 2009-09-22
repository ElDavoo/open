#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 13;

###############################################################################
# Fixtures: db
# - need a DB, but don't care what's in it
fixtures(qw( db ));

###############################################################################
# TEST: a newly created Account has *no* Groups in it.
new_account_has_no_groups: {
    my $account = create_test_account_bypassing_factory();
    my $count   = $account->group_count();
    is $count, 0, 'newly created Account has no Groups in it';

    # query list of Groups in the Account, make sure count matches
    #
    # NOTE: actual Groups returned is tested in t/ST/Groups.t
    my $groups  = $account->groups();
    isa_ok $groups, 'Socialtext::MultiCursor', 'Groups cursor';
    is $groups->count(), 0, '... with no Groups in it';
}

###############################################################################
# TEST: Group count is correct
group_count_is_correct: {
    my $account = create_test_account_bypassing_factory();

    # add some Groups, make sure the count goes up
    my $group_one = create_test_group(account => $account);
    is $account->group_count(), 1, 'Account has one Group';

    my $group_two = create_test_group(account => $account);
    is $account->group_count(), 2, 'Account has two Groups';

    # query list of Groups in the Account, make sure count matches
    #
    # NOTE: actual Groups returned is tested in t/ST/Groups.t
    my $groups = $account->groups();
    is $groups->count(), 2, 'Groups cursor has two Groups in it';
}

###############################################################################
# TEST: Group count is correct, when Groups are removed
group_count_is_correct_when_groups_removed: {
    my $account = create_test_account_bypassing_factory();

    # add some Groups, make sure the count goes up
    my $group_one = create_test_group(account => $account);
    is $account->group_count(), 1, 'Account has one Group';

    my $group_two = create_test_group(account => $account);
    is $account->group_count(), 2, 'Account has two Groups';

    # remove one of the Groups, make sure the count goes down
    $group_two->delete();
    is $account->group_count(), 1, 'Account has only one Group again';
}

###############################################################################
add_group_to_account: {
    my $account = create_test_account_bypassing_factory();
    my $group   = create_test_group();

    my $gar = $account->add_group( group => $group );

    isa_ok $gar => 'Socialtext::GroupAccountRole', 'created a GAR...';
    is $gar->account_id => $account->account_id, '... with correct account';
    is $gar->group_id => $group->group_id, '... with correct group';
    is $gar->role->name => 'member', '... with correct role';
}
