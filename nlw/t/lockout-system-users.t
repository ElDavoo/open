#!/usr/bin/perl
use strict;
use warnings;

use Test::Socialtext tests => 11;
use Test::Exception;

fixtures('db');

# Create a dummy system account and user so as not to ruin future tests.
my $sys_acct = create_test_account_bypassing_factory();
my $guest    = create_test_user(is_system_created => 1, account => $sys_acct);
my $member   = Socialtext::Role->Member();

workspace: {
    my $ws = create_test_workspace;
    dies_ok {
        $ws->add_user(user => $guest, role => $member)
    } 'add system-user to a workspace dies';
    ok $ws->has_user($guest, {direct=>1}) == 0,
        '... user was not added to workspace';

    my $auw = create_test_workspace(account => $sys_acct);
    dies_ok {
        $auw->add_account(account => $sys_acct, role => $member);
    } 'add system account to workspace (AUW) dies';
    ok $auw->has_user($guest) == 0,
        '... user was not added to workspace';

    # if a system user gets added to an AUW it can kill the whole test,
    # so forcibly remove the account if adding it happens to succeed.
    $auw->remove_account(account => $sys_acct)
        if $auw->has_account($sys_acct);
}

account: {
    my $account = create_test_account_bypassing_factory();
    dies_ok {
        $account->add_user(user => $guest, role => $member)
    } 'add system-user to an account dies';
    ok $account->has_user($guest, {direct=>1}) == 0,
        '... user was not added to account';

    dies_ok {
        $guest->primary_account($account->account_id)
    } 'change a system-user primary account dies';
    ok $account->has_user($guest, {direct=>1}) == 0,
        '... user role was not added to account';
    ok $guest->primary_account_id == $sys_acct->account_id,
        '... user primary account was not changed';
}

group: {
    my $group = create_test_group();
    dies_ok {
        $group->add_user(user => $guest, role => $member)
    } 'cannot add system-user to a group';
    ok $group->has_user($guest, {direct=>1}) == 0,
        '... user was not added to group';
}
