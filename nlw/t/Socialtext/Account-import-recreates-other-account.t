#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 47;
use Socialtext::CLI;
use Test::Socialtext::User;
use Test::Socialtext::Workspace;
use Test::Socialtext::Account;
use Test::Socialtext::CLIUtils qw(expect_success);
use File::Temp qw(tempdir);
use File::Path qw(rmtree);

###############################################################################
# Fixtures: db
fixtures(qw( db ));

###############################################################################
# TEST: when re-importing an Account that has indirect Users in it, make sure
# those Users get put back into their original Primary Account.
#
# CASE: User has Role in Workspace in Account
indirect_via_workspace: {
    my $primary_account   = create_test_account_bypassing_factory();
    my $user              = create_test_user(account => $primary_account);

    my $secondary_account = create_test_account_bypassing_factory();
    my $workspace         = create_test_workspace(account => $secondary_account);

    # Give the User access to the Secondary Account
    $workspace->add_user(user => $user);

    # Export+reimport the Account
    export_and_import_account(
        account => $secondary_account,
        flush   => sub {
            Test::Socialtext::User->delete_recklessly($user);
            Test::Socialtext::Workspace->delete_recklessly($workspace);
            Test::Socialtext::Account->delete_recklessly($primary_account);
            Test::Socialtext::Account->delete_recklessly($secondary_account);
        },
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
}

###############################################################################
# TEST: when re-importing an Account that has indirect Users in it, make sure
# those Users get put back into their original Primary Account.
#
# CASE: User has Role in Group w/Primary Account
indirect_via_group: {
    my $primary_account   = create_test_account_bypassing_factory();
    my $user              = create_test_user(account => $primary_account);

    my $secondary_account = create_test_account_bypassing_factory();
    my $group             = create_test_group(account => $secondary_account);

    # Give the User access to the Secondary Account
    $group->add_user(user => $user);

    # Export+reimport the Account
    export_and_import_account(
        account => $secondary_account,
        flush   => sub {
            Test::Socialtext::User->delete_recklessly($user);
            Test::Socialtext::Group->delete_recklessly($group);
            Test::Socialtext::Account->delete_recklessly($primary_account);
            Test::Socialtext::Account->delete_recklessly($secondary_account);
        },
    );

    # VERIFY: Both Accounts were re-created
    my $q_primary   = Socialtext::Account->new(name => $primary_account->name);
    my $q_secondary = Socialtext::Account->new(name => $secondary_account->name);
    isa_ok $q_primary, 'Socialtext::Account',
        '... Primary Account re-created';
    isa_ok $q_secondary, 'Socialtext::Account',
        '... Secondary Account re-created';

    # VERIFY: Group was re-created
    my $q_group = Socialtext::Group->GetGroup(
        primary_account_id => $q_secondary->account_id,
        driver_group_name  => $group->driver_group_name,
        created_by_user_id => $group->created_by_user_id,
    );
    isa_ok $q_group, 'Socialtext::Group', '... Group re-created';

    # VERIFY: User has correct Primary Account
    my $q_user = Socialtext::User->new(username => $user->username);
    isa_ok $q_user, 'Socialtext::User', '... User re-created';
    is $q_user->primary_account->name, $q_primary->name,
        '... ... into correct Primary Account';

    # VERIFY: User has Role in Secondary Account
    ok $q_group->has_user($q_user), '... User has Role in Group';
    ok $q_secondary->has_user($q_user), '... User has Role in Secondary Account';
}

###############################################################################
# TEST: when re-importing an Account that has indirect Users in it, make sure
# those Users get put back into their original Primary Account.
#
# CASE: User has Role in Group w/Role in Account
indirect_via_indirect_group: {
    my $primary_account   = create_test_account_bypassing_factory();
    my $user              = create_test_user(account => $primary_account);
    my $group             = create_test_group(account => $primary_account);
    $group->add_user(user => $user);

    my $secondary_account = create_test_account_bypassing_factory();

    # Give the User access to the Secondary Account
    $secondary_account->add_group(group => $group);

    # Export+reimport the Account
    export_and_import_account(
        account => $secondary_account,
        flush   => sub {
            Test::Socialtext::User->delete_recklessly($user);
            Test::Socialtext::Group->delete_recklessly($group);
            Test::Socialtext::Account->delete_recklessly($primary_account);
            Test::Socialtext::Account->delete_recklessly($secondary_account);
        },
    );

    # VERIFY: Both Accounts were re-created
    my $q_primary   = Socialtext::Account->new(name => $primary_account->name);
    my $q_secondary = Socialtext::Account->new(name => $secondary_account->name);
    isa_ok $q_primary, 'Socialtext::Account',
        '... Primary Account re-created';
    isa_ok $q_secondary, 'Socialtext::Account',
        '... Secondary Account re-created';

    # VERIFY: Group was re-created
    my $q_group = Socialtext::Group->GetGroup(
        primary_account_id => $q_primary->account_id,
        driver_group_name  => $group->driver_group_name,
        created_by_user_id => $group->created_by_user_id,
    );
    isa_ok $q_group, 'Socialtext::Group', '... Group re-created';

    # VERIFY: User has correct Primary Account
    my $q_user = Socialtext::User->new(username => $user->username);
    isa_ok $q_user, 'Socialtext::User', '... User re-created';
    is $q_user->primary_account->name, $q_primary->name,
        '... ... into correct Primary Account';

    # VERIFY: User has Role in Secondary Account
    ok $q_group->has_user($q_user), '... User has Role in Group';
    ok $q_secondary->has_group($q_group), '... Group has Role in Secondary Account';
    ok $q_secondary->has_user($q_user), '... User has Role in Secondary Account';
}

###############################################################################
# TEST: when re-importing an Account that has indirect Users in it, make sure
# those Users get put back into their original Primary Account.
#
# CASE: User has Role in Group w/Role in/WS in Account
indirect_via_group_in_workspace: {
    my $primary_account   = create_test_account_bypassing_factory();
    my $group             = create_test_group(account => $primary_account);
    my $user              = create_test_user(account => $primary_account);
    $group->add_user(user => $user);

    my $secondary_account = create_test_account_bypassing_factory();
    my $workspace = create_test_workspace(account => $secondary_account);

    # Give the User access to the Secondary Account
    $workspace->add_group(group => $group);

    # Export+reimport the Account
    export_and_import_account(
        account => $secondary_account,
        flush   => sub {
            Test::Socialtext::User->delete_recklessly($user);
            Test::Socialtext::Group->delete_recklessly($group);
            Test::Socialtext::Workspace->delete_recklessly($workspace);
            Test::Socialtext::Account->delete_recklessly($primary_account);
            Test::Socialtext::Account->delete_recklessly($secondary_account);
        },
    );

    # VERIFY: Both Accounts were re-created
    my $q_primary   = Socialtext::Account->new(name => $primary_account->name);
    my $q_secondary = Socialtext::Account->new(name => $secondary_account->name);
    isa_ok $q_primary, 'Socialtext::Account',
        '... Primary Account re-created';
    isa_ok $q_secondary, 'Socialtext::Account',
        '... Secondary Account re-created';

    # VERIFY: Group was re-created
    my $q_group = Socialtext::Group->GetGroup(
        primary_account_id => $q_primary->account_id,
        driver_group_name  => $group->driver_group_name,
        created_by_user_id => $group->created_by_user_id,
    );
    isa_ok $q_group, 'Socialtext::Group', '... Group re-created';

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
    ok $q_group->has_user($q_user), '... User has Role in Group';
    ok $q_workspace->has_group($q_group), '... Group has Role in Workspace';
    ok $q_secondary->has_user($q_user), '... User has Role in Secondary Account';
}


###############################################################################
# Helper function; export and re-import the Account.
sub export_and_import_account {
    my %args    = @_;
    my $account = $args{account};
    my $flush   = $args{flush} || sub { };

    my $export_base = tempdir(CLEANUP => 1);
    my $export_dir  = File::Spec->catdir($export_base, 'account');

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [
                    '--account', $account->name,
                    '--dir',     $export_dir,
                ],
            )->export_account();
        },
        qr/account exported to/,
        'Account exported',
    );

    # Flush our test data.
    $flush->();
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

    # CLEANUP
    rmtree [$export_base], 0;
}
