#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 26;
use Test::Exception;
use Socialtext::GroupAccountRoleFactory;

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
# TEST: Add Group to Account with default Role.
add_group_to_account: {
    my $account = create_test_account_bypassing_factory();
    my $group   = create_test_group();

    my $gar = $account->add_group( group => $group );

    isa_ok $gar => 'Socialtext::GroupAccountRole', 'created a GAR...';
    is $gar->account_id => $account->account_id, '... with correct account';
    is $gar->group_id   => $group->group_id,     '... with correct group';
    is $gar->role->name => 'member', '... with correct role';
}

###############################################################################
# TEST: Add Group to Account with explicit Role.
add_group_to_account_explicit_role: {
    my $account = create_test_account_bypassing_factory();
    my $group   = create_test_group();
    my $role    = Socialtext::Role->Affiliate();

    my $gar = $account->add_group( group => $group, role => $role );

    isa_ok $gar => 'Socialtext::GroupAccountRole', 'created a GAR...';
    is $gar->account_id => $account->account_id, '... with correct account';
    is $gar->group_id   => $group->group_id,     '... with correct group';
    is $gar->role->name => $role->name,          '... with correct role';
}

###############################################################################
# TEST: Check if Group has a Role in an Account
group_has_role_in_account: {
    my $account = create_test_account_bypassing_factory();
    my $group   = create_test_group();

    ok !$account->has_group($group), 'Group does not yet have Role in Account';
    $account->add_group(group => $group);
    ok  $account->has_group($group), '... Group has been added to Account';
}

###############################################################################
# TEST: What Role does the Group have in the Account
what_role_does_group_have_in_account: {
    my $account = create_test_account_bypassing_factory();
    my $group   = create_test_group();

    $account->add_group(group => $group);
    is $account->group_count(), 1, 'Group was added to Account';

    my $default_role = Socialtext::GroupAccountRoleFactory->DefaultRole();
    my $groups_role  = $account->role_for_group(group => $group);
    is $groups_role->name, $default_role->name,
        '... with Default GAR Role';
}

###############################################################################
# TEST: Remove Group from Account
remove_group_from_account: {
    my $account = create_test_account_bypassing_factory();
    my $group   = create_test_group();

    # Account should not (yet) have this Group
    ok !$account->has_group($group), 'Group does not yet have Role in Account';

    # Add the Group to the Account
    $account->add_group(group => $group);
    ok $account->has_group($group), '... Group has been added to Account';

    # Remove the Group from the Account
    $account->remove_group(group => $group);
    ok !$account->has_group($group), '... Group has been removed from Account';
}

###############################################################################
# TEST: Remove Group from Account, when the Group has *no* Role in the Account
remove_non_member_group_from_account: {
    my $account = create_test_account_bypassing_factory();
    my $group   = create_test_group();

    # Account should not (yet) have this Group
    ok !$account->has_group($group), 'Group does not yet have Role in Account';

    # Removing a non-member Group from the Account shouldn't choke.  No
    # errors, no warnings, no fatal exceptions... its basically a no-op.
    lives_ok { $account->remove_group(group => $group) }
        "... removing non-member Group from Account doesn't choke";
}
