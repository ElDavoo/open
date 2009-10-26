#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Test::Socialtext tests => 2;
use Test::Socialtext::User;
use Test::Socialtext::Group;
use Test::Socialtext::Workspace;
use Test::Socialtext::Account;
use Test::Differences;
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
    my $export_dir = tempdir(CLEANUP => 1);
    my $tarball    = $workspace->export_to_tarball(dir => $export_dir);

    # Flush; WS, Group, both Accounts
    Test::Socialtext::Group->delete_recklessly($group);
    Test::Socialtext::Workspace->delete_recklessly($workspace);
    Test::Socialtext::Account->delete_recklessly($primary_account);
    Test::Socialtext::Account->delete_recklessly($secondary_account);
    Socialtext::Cache->clear();

    # Import the Workspace
    Socialtext::Workspace->ImportFromTarball(tarball => $tarball);

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

    # CLEANUP
    rmtree [$export_dir], 0;
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
    my $export_dir = tempdir(CLEANUP => 1);
    my $tarball    = $workspace->export_to_tarball(dir => $export_dir);

    # Change the Group membership, so we can verify that membership gets
    # merged in.
    $group->remove_user(user => $user_one);
    $group->add_user(user => $user_two);

    # Flush the Workspace we're re-importing
    Test::Socialtext::Workspace->delete_recklessly($workspace);
    Socialtext::Cache->clear();

    # Import the Workspace
    Socialtext::Workspace->ImportFromTarball(tarball => $tarball);

    # VERIFY: Group membership list was merged
    my @expected = map { $_->username } ($user_one, $user_two);
    my @received = map { $_->username } $group->users->all;
    eq_or_diff \@received, \@expected,
        'Group membership list merged on Workspace import';

    # CLEANUP
    rmtree [$export_dir], 0;
}
