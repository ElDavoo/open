#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::Socialtext tests => 8;
use Test::Output qw(combined_from);
use Carp qw/confess/;
use Socialtext::CLI;
use Test::Socialtext::CLIUtils;

# Only need a DB.
fixtures(qw(db));

################################################################################
# TEST: add account to workspace
add_account_to_workspace: {
    my $account   = create_test_account_bypassing_factory();
    my $acct_name = $account->name;
    my $ws        = create_test_workspace(account => $account);
    my $ws_name   = $ws->name;
    my $user      = create_test_user();

    $account->add_user(user => $user);
    $ws->add_user(user => $user);

    my $output = combined_from( sub { eval {
            Socialtext::CLI->new(
                argv => [
                    '--workspace' => $ws_name,
                    '--account'   => $acct_name,
                ],
            )->add_member();
    } } );
    like $output, qr/$acct_name now has the role of 'member' in the $ws_name Workspace/,
        '... with correct message';

    {
        my $role = $ws->role_for_account($account);
        is $role->role_id => Socialtext::Role->Member()->role_id,
           '... with correct role';
    }
    {
        my $role = $ws->role_for_user($user, direct => 1);
        ok !$role, 'user has direct ws role removed';
    }
}

################################################################################
# TEST: add account to ws, account already exists
account_already_exists: {
    my $account   = create_test_account_bypassing_factory();
    my $ws        = create_test_workspace(account => $account);
    my $acct_name = $account->name;
    my $ws_name   = $ws->name;

    $ws->add_account(account => $account);

    my $output = combined_from( sub { eval {
            Socialtext::CLI->new(
                argv => [
                        '--account' => $acct_name,
                        '--workspace' => $ws_name,
                ],
            )->add_member();
    } } );
    like $output, qr/$acct_name already has the role of 'member' in the $ws_name Workspace/,
        '... with correct message';
}

################################################################################
# TEST: add non-primary account to ws, should fail
account_is_not_primary_account: {
    my $account   = create_test_account_bypassing_factory();
    my $ws        = create_test_workspace();
    my $acct_name = $account->name;
    my $ws_name   = $ws->name;

    my $output = combined_from( sub { eval {
            Socialtext::CLI->new(
                argv => [
                        '--account' => $acct_name,
                        '--workspace' => $ws_name,
                ],
            )->add_member();
    } } );
    like $output, qr/Only a workspace's primary account can be a member\./,
        'account is not the primary account';
    ok !$ws->role_for_account($account), '... not a member';
}

################################################################################
# TEST: remove Account from Workspace
remove_account_from_workspace: {
    my $account   = create_test_account_bypassing_factory();
    my $ws        = create_test_workspace(account => $account);
    my $acct_name = $account->name;
    my $ws_name   = $ws->name;

    $ws->add_account(account => $account);

    my $output = combined_from( sub { eval {
        Socialtext::CLI->new(
            argv => [
                '--account' => $acct_name,
                '--workspace' => $ws_name,
            ],
        )->remove_member();
    } } );

    like $output, qr/$acct_name is no longer a member of $ws_name/,
        '... with correct message';
    is $ws->has_account($account) => 0, '... account is not in workspace';
}


#TODO
# * Test that we can't add accounts to groups
exit;

