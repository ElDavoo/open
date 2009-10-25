#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 11;
use Socialtext::CLI;
use Test::Socialtext::User;
use Test::Socialtext::Workspace;
use Test::Socialtext::Account;
use t::Socialtext::CLITestUtils qw(expect_success);
use File::Temp qw(tempdir);
use File::Path qw(rmtree);

###############################################################################
# Fixtures: db
fixtures(qw( db ));

###############################################################################
# TEST: when re-importing an Account that has Users in it that do *not* have
# this Account as their Primary Account, make sure that those other Accounts
# get properly recreated.  e.g. User has Primary Account elsewhere but has a
# Role in this Account (which is how he ended up in our export).
import_recreates_other_account: {
    my $primary_account   = create_test_account_bypassing_factory();
    my $user              = create_test_user(account => $primary_account);

    my $secondary_account = create_test_account_bypassing_factory();
    my $workspace         = create_test_workspace(account => $secondary_account);

    # Give the User access to the Secondary Account
    $workspace->add_user(user => $user);

    # Export the Account.
    my $export_base = tempdir(CLEANUP => 1);
    my $export_dir  = File::Spec->catdir($export_base, 'account');

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [
                    '--account', $secondary_account->name,
                    '--dir',     $export_dir,
                ],
            )->export_account();
        },
        qr/account exported to/,
        'Account exported',
    );

    # Flush our test data.
    Test::Socialtext::User->delete_recklessly($user);
    Test::Socialtext::Workspace->delete_recklessly($workspace);
    Test::Socialtext::Account->delete_recklessly($primary_account);
    Test::Socialtext::Account->delete_recklessly($secondary_account);
    Socialtext::Cache->clear();

    # Re-import the Account.
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => ['--dir', $export_dir],
            )->import_account();
        },
        qr/account imported/,
        '... Account re-imported',
    );

    # VERIFY: Both Accounts were re-created
    my $q_primary   = Socialtext::Account->new(name => $primary_account->name);
    my $q_secondary = Socialtext::Account->new(name => $secondary_account->name);
    isa_ok $q_primary, 'Socialtext::Account',
        '... Primary Account re-created';
    isa_ok $q_secondary, 'Socialtext::Account',
        '... Secondary Account re-created';

    # VERIFY: Workspace was re-created
    my $q_workspace = Socialtext::Workspace->new(name => $workspace->name);
    isa_ok $q_workspace, 'Socialtext::Workspace',
        '... Workspace re-created';

    # VERIFY: User has correct Primary Account
    my $q_user = Socialtext::User->new(username => $user->username);
    isa_ok $q_user, 'Socialtext::User', '... User re-created';
    is $q_user->primary_account->name, $q_primary->name,
        '... ... into correct Primary Account';

    # VERIFY: User has Role in Secondary Account
    ok $q_workspace->has_user($q_user), '... User has Role in Workspace';
    ok $q_secondary->has_user($q_user), '... User has Role in Secondary Account';

    # CLEANUP
    rmtree [$export_base], 0;
}
