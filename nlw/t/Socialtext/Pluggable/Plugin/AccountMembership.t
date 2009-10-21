#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 13;

fixtures(qw( db ));

###############################################################################
# TEST: Group has a "Member" Role in its Primary Account.
groups_role_in_primary_account: {
    my $account = create_test_account_bypassing_factory();
    my $group   = create_test_group(account => $account);
    my $member  = Socialtext::Role->Member();

    is $account->role_for_group(group => $group)->name, $member->name,
        'Group has Member Role in Primary Account';
}

###############################################################################
# TEST: Group has an "Affiliate" Role in any secondary Account that it happens
# to have a Workspace membership in.
groups_role_in_secondary_account: {
    my $account   = create_test_account_bypassing_factory();
    my $ws        = create_test_workspace(account => $account);
    my $group     = create_test_group();
    my $affiliate = Socialtext::Role->Affiliate();

    $ws->add_group(group => $group);
    is $account->role_for_group(group => $group)->name, $affiliate->name,
        'Group has Affiliate Role in Secondary Accounts';
}

###############################################################################
# TEST: Group is explicitly a "Member" in an Account.  Adding the Group to a
# WS in that Account does not overwrite their "Member" Role.
no_overwrite_of_member_role_in_account: {
    my $acct   = create_test_account_bypassing_factory();
    my $ws     = create_test_workspace(account => $acct);
    my $group  = create_test_group();
    my $member = Socialtext::Role->Member();

    $acct->add_group(group => $group);
    is $acct->role_for_group(group => $group)->name, $member->name,
        'Group has Member Role in test Account';

    $ws->add_group(group => $group);
    is $acct->role_for_group(group => $group)->name, $member->name,
        '... added Group to WS in Account; Role in Account unchanged';
}

###############################################################################
# TEST: Group is explicitly a "Member" in an Account.  Removing the Group from
# a WS in that Account does not overwrite/remove their "Member" Role.
no_teardown_of_member_role_in_account: {
    my $acct   = create_test_account_bypassing_factory();
    my $ws     = create_test_workspace(account => $acct);
    my $group  = create_test_group();
    my $member = Socialtext::Role->Member();

    $acct->add_group(group => $group);
    is $acct->role_for_group(group => $group)->name, $member->name,
        'Group has Member Role in test Account';

    $ws->add_group(group => $group);
    ok $ws->has_group($group), '... added Group to WS';
    is $acct->role_for_group(group => $group)->name, $member->name,
        '... ... Role in its Account is unchanged';

    $ws->remove_group(group => $group);
    is $acct->role_for_group(group => $group)->name, $member->name,
        '... Group removed from WS; Role in Account unchanged';
}

###############################################################################
# TEST: Group is "Member" of a WS, giving them an Affiliate Role in the WS's
# Account.  Adding the Group to that Account upgrades their GAR to "Member".
role_upgrade: {
    my $acct      = create_test_account_bypassing_factory();
    my $ws        = create_test_workspace(account => $acct);
    my $group     = create_test_group();
    my $member    = Socialtext::Role->Member();
    my $affiliate = Socialtext::Role->Affiliate();

    $ws->add_group(group => $group);
    is $acct->role_for_group(group => $group)->name, $affiliate->name,
        'Group has Affiliate Role in secondary Account';

    $acct->add_group(group => $group);
    is $acct->role_for_group(group => $group)->name, $member->name,
        '... adding Group to Account upgrades to Member Role';
}

###############################################################################
# TEST: Group is "Member" of a WS _and_ its Account.  Removing the Group from
# the Account downgrades its "Member" Role to "Affiliate" (because the Group
# still has a Role in the Workspace).
role_downgrade: {
    my $acct      = create_test_account_bypassing_factory();
    my $ws        = create_test_workspace(account => $acct);
    my $group     = create_test_group();
    my $member    = Socialtext::Role->Member();
    my $affiliate = Socialtext::Role->Affiliate();

    $ws->add_group(group => $group);
    is $acct->role_for_group(group => $group)->name, $affiliate->name,
        'Group has Affiliate Role in secondary Account';

    $acct->add_group(group => $group);
    is $acct->role_for_group(group => $group)->name, $member->name,
        '... adding Group to Account upgrades to Member Role';

    $acct->remove_group(group => $group);
    is $acct->role_for_group(group => $group)->name, $affiliate->name,
        '... removing Group from Account downgrades to Affiliate Role';
}
