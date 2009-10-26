#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Test::Socialtext tests => 7;
use Test::Socialtext::User;
use Test::Socialtext::Group;
use Test::Socialtext::Workspace;
use Test::Socialtext::Account;
use Test::Differences;
use Socialtext::CLI;
use t::Socialtext::CLITestUtils qw(expect_success);
use File::Temp qw(tempdir);
use File::Path qw(rmtree);

###############################################################################
# CASE: Have "Default" Group, export w/Workspace, flush, Group is
# re-constituted on Workspace import, into its original Primary Account.
reconstitute_default_group_on_workspace_import: {
    my $primary_account   = create_test_account_bypassing_factory();
    my $group             = create_test_group(account => $primary_account);
    my $secondary_account = create_test_account_bypassing_factory();
    my $workspace = create_test_workspace(account => $secondary_account);

    # Add the Group to the Workspace
    $workspace->add_group(group => $group);

    # Export the Workspace
    export_and_import_workspace(
        workspace => $workspace,
        flush     => sub {
            Test::Socialtext::Group->delete_recklessly($group);
            Test::Socialtext::Workspace->delete_recklessly($workspace);
            Test::Socialtext::Account->delete_recklessly($primary_account);
            Test::Socialtext::Account->delete_recklessly($secondary_account);
        },
    );

    # VERIFY: Group exists w/correctPrimary Account
    my $q_primary = Socialtext::Account->new(
        name => $primary_account->name,
    );
    my $q_group = Socialtext::Group->GetGroup(
        primary_account_id => $q_primary->account_id,
        driver_group_name  => $group->driver_group_name,
        created_by_user_id => $group->created_by_user_id,
    );
    isa_ok $q_group, 'Socialtext::Group',
        'Group reconstituted, w/correct Primary Account';
}

###############################################################################
# CASE: Have "Default" Group, export w/Workspace, Group membership list is
# merged on Workspace import.
merge_default_group_on_workspace_import: {
    my $primary_account   = create_test_account_bypassing_factory();
    my $group             = create_test_group(account => $primary_account);
    my $user_one          = create_test_user(account => $primary_account);
    my $user_two          = create_test_user(account => $primary_account);
    my $secondary_account = create_test_account_bypassing_factory();
    my $workspace = create_test_workspace(account => $secondary_account);

    # Add the Group to the Workspace
    $group->add_user(user => $user_one);
    $workspace->add_group(group => $group);

    # Export the Workspace
    export_and_import_workspace(
        workspace => $workspace,
        flush => sub {
            # change Group membership, so we can verify that membership gets
            # merged in properly
            $group->remove_user(user => $user_one);
            $group->add_user(user => $user_two);

            # flush workspace
            Test::Socialtext::Workspace->delete_recklessly($workspace);
        },
    );

    # VERIFY: Group membership list was merged
    my @expected = map { $_->username } ($user_one, $user_two);
    my @received = map { $_->username } $group->users->all;
    eq_or_diff \@received, \@expected,
        'Group membership list merged on Workspace import';
}

###############################################################################
# CASE: Have "Default" Group, export w/Account, flush, Group is re-constituted
# on Account import, into original Primary Account.
reconsitute_default_group_on_account_import: {
    my $primary_account   = create_test_account_bypassing_factory();
    my $group             = create_test_group(account => $primary_account);
    my $secondary_account = create_test_account_bypassing_factory();
    my $workspace = create_test_workspace(account => $secondary_account);

    # Add the Group to the Workspace
    $workspace->add_group(group => $group);

    # Export the Account
    export_and_import_account(
        account => $secondary_account,
        flush   => sub {
            Test::Socialtext::Group->delete_recklessly($group);
            Test::Socialtext::Workspace->delete_recklessly($workspace);
            Test::Socialtext::Account->delete_recklessly($primary_account);
            Test::Socialtext::Account->delete_recklessly($secondary_account);
        },
    );

    # VERIFY: Group exists w/correctPrimary Account
    my $q_primary = Socialtext::Account->new(
        name => $primary_account->name,
    );
    my $q_group = Socialtext::Group->GetGroup(
        primary_account_id => $q_primary->account_id,
        driver_group_name  => $group->driver_group_name,
        created_by_user_id => $group->created_by_user_id,
    );
    isa_ok $q_group, 'Socialtext::Group',
        'Group reconstituted, w/correct Primary Account';
}


###############################################################################
# Helper method to export+reimport Account.
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

###############################################################################
# Helper method to export+reimport Workspace.
sub export_and_import_workspace {
    my %args = @_;
    my $workspace = $args{workspace};
    my $flush   = $args{flush} || sub { };

    my $export_dir = tempdir(CLEANUP => 1);
    my $tarball = $workspace->export_to_tarball(dir => $export_dir);

    # Flush our test data.
    $flush->();
    Socialtext::Cache->clear();

    # Re-import the Workspace.
    Socialtext::Workspace->ImportFromTarball(tarball => $tarball);

    # CLEANUP
    rmtree [$export_dir], 0;
}
