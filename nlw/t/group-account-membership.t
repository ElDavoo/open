#!/usr/bin/perl
# @COPYRIGHT@
use warnings;
use strict;

# This test asserts that API activity matches up with group_account_role table
# contents.

use Test::Socialtext tests => 17;
use Socialtext::SQL qw/:exec/;
use Socialtext::Group;
use Socialtext::Account;
use Socialtext::Workspace;
use Socialtext::Role;
use Socialtext::Pluggable::Adapter;

fixtures( 'db' );

sub account_role_count_is ($$;$) {
    my $acct = shift;
    my $expected = shift;
    my $comment = shift;

    my $count = sql_singlevalue(q{
        SELECT COUNT(1)
          FROM group_account_role
         WHERE account_id = ?
    }, $acct->account_id);

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    is $count, $expected, $comment;
}

sub check_group_account_role($$;$$) {
    my $group = shift;
    my $account = shift || Socialtext::Account->Default;
    my $role = shift || Socialtext::Role->Member;
    my $comment = shift;

    $role = Socialtext::Role->$role unless ref($role);

    my $count = sql_singlevalue(q{
        SELECT COUNT(1)
          FROM group_account_role
         WHERE group_id = ? AND account_id = ? AND role_id = ?
    }, $group->group_id, $account->account_id, $role->role_id);

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    is $count => 1, $comment;
}

# watch account membership as we add and remove a group to/from an account
via_direct_roles: {
    my $acct = create_test_account_bypassing_factory();
    my $group = create_test_group(); # some other primary account
    my $group2 = create_test_group(); # some other primary account

    account_role_count_is $acct => 0, "no roles initially";

    my @gars;
    push @gars, Socialtext::GroupAccountRoleFactory->Create({
        group_id => $_->group_id,
        role_id => Socialtext::Role->Member->role_id,
        account_id => $acct->account_id,
    }) for ($group, $group2);

    account_role_count_is $acct => 2, "two new roles";
    check_group_account_role $group, $acct;
    check_group_account_role $group2, $acct;

    Socialtext::GroupAccountRoleFactory->Delete($_) for @gars;

    account_role_count_is $acct => 0, "no roles after deletion";
}

# account membership is set up when Group is created
via_primary_account: {
    my $acct  = create_test_account_bypassing_factory();
    my $acct2 = create_test_account_bypassing_factory();
    my $group = create_test_group(account => $acct);

    my $gar = Socialtext::GroupAccountRoleFactory->Create({
        group_id => $group->group_id,
        role_id => Socialtext::Role->Member->role_id,
        account_id => $acct2->account_id,
    });
    isa_ok $gar, 'Socialtext::GroupAccountRole', 'explicit GAR';

    account_role_count_is $acct => 1;
    check_group_account_role $group, $acct, 'Affiliate',
        "primary account is an affiliate relationship";

    account_role_count_is $acct2 => 1;
    check_group_account_role $group, $acct2, 'Member',
        "membership in the other account";

    Socialtext::GroupAccountRoleFactory->Delete($gar);

    account_role_count_is($acct => 1, "affiliate role retained");
    account_role_count_is($acct2 => 0, "member role removed");
}

# watch account membership as we add and remove a group to/from a workspace
via_workspace: {
    my $acct = create_test_account_bypassing_factory();
    my $ws = create_test_workspace(account => $acct);
    my $group = create_test_group(); # some other account

    account_role_count_is $acct => 0, "no roles initially";

    my $gwr = $ws->add_group(group => $group);
    ok $gwr;

    account_role_count_is $acct => 1;
    check_group_account_role $group, $acct, 'Affiliate',
        "group is an affiliate through the workspace";

    $ws->remove_group(group => $group);

    account_role_count_is $acct => 0, 
        "removing group workspace role removes the affiliate role";
}
