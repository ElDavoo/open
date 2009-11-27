#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 130;
use Test::Differences;
use Socialtext::CLI;
use Test::Socialtext::User;
use Test::Socialtext::Group;
use Test::Socialtext::Workspace;
use Test::Socialtext::Account;
use t::Socialtext::CLITestUtils qw(expect_success);
use File::Temp qw(tempdir);
use File::Path qw(rmtree);
use Data::Dumper;

###############################################################################
# Fixtures: db
fixtures(qw( db ));

###############################################################################
# Grab short-hand versions of the Roles we're going to use
my $Affiliate      = Socialtext::Role->Affiliate();
my $Member         = Socialtext::Role->Member();
my $WorkspaceAdmin = Socialtext::Role->Admin();

###############################################################################
# Helper function to export, flush, and re-import an Account.
our $DumpRoles = 0;
sub export_and_reimport_account {
    my %args            = @_;
    my $acct            = $args{account};
    my @users           = $args{users} ? @{ $args{users} } : ();
    my @groups          = $args{groups} ? @{ $args{groups} } : ();
    my @workspaces      = $args{workspaces} ? @{ $args{workspaces} } : ();
    my $cb_after_export = $args{after_export} || sub { };

    my $export_base = tempdir(CLEANUP => 1);
    my $export_dir  = File::Spec->catdir($export_base, 'account');

    # Build up the list of Roles that exist *before* the export/import
    my @gars = map { _dump_gars($_) } $acct;
    my @uars = map { _dump_uars($_) } $acct;
    my @uwrs = map { _dump_uwrs($_) } @workspaces;
    my @gwrs = map { _dump_gwrs($_) } @workspaces;
    my @ugrs = map { _dump_ugrs($_) } @groups;

    # Export the Account
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => ['--account', $acct->name, '--dir', $export_dir],
            )->export_account(),
        },
        qr/account exported to/,
        '... Account exported',
    );

    # Flush the system, cleaning out the test Users/Workspaces/Accounts.
    #
    # *DON'T* use a list traversal operation that could manipulate the
    # original list/objects, though; we're going to need them again in a
    # moment.
    $cb_after_export->();
    foreach my $user (@users) {
        Test::Socialtext::User->delete_recklessly($user);
    }
    foreach my $group (@groups) {
        Test::Socialtext::Group->delete_recklessly($group);
    }
    foreach my $ws (@workspaces) {
        Test::Socialtext::Workspace->delete_recklessly($ws);
    }
    Test::Socialtext::Account->delete_recklessly($acct);
    Socialtext::Cache->clear();

    # Re-import the Account
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => ['--dir', $export_dir],
            )->import_account();
        },
        qr/account imported/,
        '... Account re-imported',
    );

    # Load up copies of all of the Accounts/Workspaces/Groups that exist after
    # the export/import.  Yes, this is a bit ugly (especially for Groups,
    # where on re-import, the unique key is going to change for the Group;
    # primary_account_id changes).
    my $imported_acct = Socialtext::Account->new(name => $acct->name);

    my @imported_workspaces =
        map { Socialtext::Workspace->new(name => $_->name) }
        @workspaces;

    my @imported_groups;
    foreach my $group (@groups) {
        my $primary_account = Socialtext::Account->new(
            name => $group->primary_account->name,
        );
        my $primary_acct_id    = $primary_account->account_id;
        my $created_by_user_id = $group->created_by_user_id;
        my $group_name         = $group->driver_group_name;
        push @imported_groups, Socialtext::Group->GetGroup(
            primary_account_id => $primary_acct_id,
            created_by_user_id => $created_by_user_id,
            driver_group_name  => $group_name,
        );
    }

    # Get the list of Roles that exist *after* the export/import
    my @imported_gars = map { _dump_gars($_) } $imported_acct;
    my @imported_uars = map { _dump_uars($_) } $imported_acct;
    my @imported_uwrs = map { _dump_uwrs($_) } @imported_workspaces;
    my @imported_gwrs = map { _dump_gwrs($_) } @imported_workspaces;
    my @imported_ugrs = map { _dump_ugrs($_) } @imported_groups;

    # Role list *should* be the same after import
    eq_or_diff \@imported_gars, \@gars, '... GroupAccountRoles preserved';
    eq_or_diff \@imported_uars, \@uars, '... UserAccountRoles preserved';
    eq_or_diff \@imported_uwrs, \@uwrs, '... UserWorkspaceRoles preserved';
    eq_or_diff \@imported_gwrs, \@gwrs, '... GroupWorkspaceRoles preserved';
    eq_or_diff \@imported_ugrs, \@ugrs, '... UserGroupRoles preserved';

    # (debugging) Dump the Roles
    if ($DumpRoles) {
        diag "GroupAccountRoles: "   . Dumper(\@gars);
        diag "UserAccountRoles: "    . Dumper(\@uars);
        diag "UserWorkspaceRoles: "  . Dumper(\@uwrs);
        diag "GroupWorkspaceRoles: " . Dumper(\@gwrs);
        diag "UserGroupRoles: "      . Dumper(\@ugrs);
    }

    # CLEANUP: remove our temp directory
    rmtree([$export_base], 0);
}

###############################################################################
# TEST: Account export/import preserves GAR, when Group has this Account as
# its Primary Account.
account_import_preserves_gar_primary_account: {
    ok 1, 'TEST: Preserves GARs; Groups Primary Account';
    my $account = create_test_account_bypassing_factory();
    my $group   = create_test_group(account => $account);

    # Export and re-import the Account; GAR should be preserved
    export_and_reimport_account(
        account => $account,
        groups  => [$group],
    );
}

###############################################################################
# TEST: Account export/import preserves GAR, when Group has a Role in this
# Account (but its not the Groups Primary Account).
account_import_preserves_gar: {
    ok 1, 'TEST: Preserves GARs; Group has Role in Account';
    my $account    = create_test_account_bypassing_factory();
    my $acct_name  = $account->name();

    my $group      = create_test_group();
    my $group_name = $group->driver_group_name();

    # Give the Group a direct Role in the Account
    #
    # NOTE: as of 2009-10-22, the only supported GARs are Affiliate and Member
    $account->add_group(
        group => $group,
        role  => $Member,
    );

    # Export and re-import the Account; GAR should be preserved
    export_and_reimport_account(
        account => $account,
        groups  => [$group],
    );
}

###############################################################################
# TEST: Account export/import preserves GWRs/GARs
#
# Group can have an *indirect* Role in an Account by virtue of being a member
# in a Workspace that lives within the Account.  Make sure that the Role is
# preserved across export/import.
account_import_preserves_gwrs: {
    ok 1, 'TEST: Preserves GWRs/GARs';
    my $account    = create_test_account_bypassing_factory();
    my $acct_name  = $account->name();

    my $workspace  = create_test_workspace(account => $account);
    my $ws_name    = $workspace->name();

    my $group      = create_test_group();
    my $group_name = $group->driver_group_name();

    # Give the Group a Role in a Workspace, indirectly giving it a Role in the
    # Account.
    $workspace->add_group(
        group => $group,
        role  => $WorkspaceAdmin,
    );

    # Export and re-import the Account; GWRs/GARs should be preserved
    export_and_reimport_account(
        account    => $account,
        groups     => [$group],
        workspaces => [$workspace],
    );
}

###############################################################################
# TEST: Account export/import preserves GARs + GWRs/GARs
#
# Group can have both a *direct* and an *indirect* Role in an Account.  By the
# time it ends up in the DB its just a single GAR entry, but this test also
# verifies that the GWR was properly preserved.
account_import_preserves_direct_and_indirect_group_roles: {
    ok 1, 'TEST: Preserves GARs + GWRs/GARs';
    my $account   = create_test_account_bypassing_factory();
    my $acct_name = $account->name();

    my $workspace = create_test_workspace(account => $account);
    my $ws_name   = $workspace->name();

    my $group     = create_test_group();

    # Give the Group both a direct and an indirect Role in the Account.
    $account->add_group(group => $group, role => $Member);
    $workspace->add_group(group => $group);

    # Export and re-import the Account; GWRs/GARs should be preserved
    export_and_reimport_account(
        account    => $account,
        groups     => [$group],
        workspaces => [$workspace],
    );
}

###############################################################################
# TEST: Account export/import preserves multiple GWRs/GARs
#
# Group can have multiple *indirect* Roles in an Account.  Make sure that
# they're all preserved across export/import.
account_import_preserves_multiple_indirect_roles: {
    ok 1, 'TEST: Preserves multiple GWRs/GARs';
    my $account = create_test_account_bypassing_factory();
    my $ws_one  = create_test_workspace(account => $account);
    my $ws_two  = create_test_workspace(account => $account);
    my $group   = create_test_group();

    # Give the Group some Roles in multiple Workspaces
    $ws_one->add_group(
        group => $group,
        role  => $Member,
    );
    $ws_two->add_group(
        group => $group,
        role  => $WorkspaceAdmin,
    );

    # Export and re-import the Account
    export_and_reimport_account(
        account    => $account,
        groups     => [$group],
        workspaces => [$ws_one, $ws_two],
    );
}

###############################################################################
# TEST: Account export/import preserves UAR, when User has this Account as its
# Primary Account.
account_import_preserves_uar_primary_account: {
    ok 1, 'TEST: Preserves UARs; Users Primary Account';
    my $account = create_test_account_bypassing_factory();
    my $user    = create_test_user(account => $account);

    # Export and re-import the Account; UAR should be preserved
    export_and_reimport_account(
        account => $account,
        users   => [$user],
    );
}

###############################################################################
# TEST: preserve direct UAR
#
# User can have a *direct* Role in an Account (which as of 2009-10-22 is only
# supported via their "Primary Account").  Make sure that the Role is
# preserved across export/import.
#
# Users can also have a membership in an Account, which should also be
# preserved across export/import.
account_import_preserves_uar: {
    ok 1, 'TEST: Preserves direct UAR';
    my $account   = create_test_account_bypassing_factory();
    my $acct_name = $account->name();

    my $user      = create_test_user();
    my $user_name = $user->username();

    # give the User a direct Role in the Account
    my $orig_role = $Member;
    $account->add_user(user => $user, role => $orig_role);

    # Export and re-import the Account
    export_and_reimport_account(
        account => $account,
        users   => [$user],
    );

    # User should have the correct Role in the Account
    $account = Socialtext::Account->new(name => $acct_name);
    isa_ok $account, 'Socialtext::Account', '... found re-imported Account';

    $user = Socialtext::User->new(username => $user_name);
    isa_ok $user, 'Socialtext::User', '... found re-imported User';

    my $role = $account->role_for_user(user => $user);
    ok defined $role, '... User has Role in Account';
    is $role->name, $orig_role->name, '... ... with *correct* Role';
}

###############################################################################
# TEST: preserve indirect UWR
#
# User can have an *indirect* Role in an Account by virtue of being a member
# in a Workspace that lives within the Account.  Make sure that the Role is
# preserved across export/import.
account_import_preserves_uwr: {
    ok 1, 'TEST: Preserves indirect UWR';
    my $account   = create_test_account_bypassing_factory();
    my $acct_name = $account->name();

    my $workspace = create_test_workspace(account => $account);
    my $ws_name   = $workspace->name();

    my $user      = create_test_user();
    my $user_name = $user->username();

    # PRE-CHECK: User shouldn't be in our test Account
    ok !$account->has_user($user), '... User not in test Account (yet)';

    # give the User a Role in the Workspace, which gives them an *indirect*
    # Role in the Account.
    $workspace->add_user(user => $user, role => $Member);

    # User should now be in the test Account
    my $orig_role = $account->role_for_user(user => $user);
    ok defined $orig_role , '... User now has a Role in the Account';

    # Export and re-import the Account; UWRs/UARs should be preserved
    export_and_reimport_account(
        account    => $account,
        workspaces => [$workspace],
        users      => [$user],
    );

    # User should have the correct Role in the Account
    $account = Socialtext::Account->new(name => $acct_name);
    isa_ok $account, 'Socialtext::Account', '... found re-imported Account';

    $user = Socialtext::User->new(username => $user_name);
    isa_ok $user, 'Socialtext::User', '... found re-imported User';

    my $role = $account->role_for_user(user => $user);
    ok defined $role, '... User has Role in Account';
    is $role->name, $orig_role->name, '... ... with *correct* Role';
}

###############################################################################
# Test: preserve indirect UGR/GAR
#
# User can have an *indirect* Role in an Account by virtue of being a member
# of a Group that happens to have a Role in the Account.  Make sure that Role
# is preserved across export/import.
account_import_preserves_user_indirect_role_through_group: {
    ok 1, 'TEST: Preserves UGRs/GARs';
    my $account = create_test_account_bypassing_factory();
    my $group   = create_test_group(account => $account);
    my $user    = create_test_user();

    # Add the User to the Account through a Group membership.
    $group->add_user(user => $user);

    # Export and re-import the Account
    export_and_reimport_account(
        account    => $account,
        groups     => [$group],
        users      => [$user],
    );
}

###############################################################################
# TEST: preserve indirect UGR/GWR/GAR
#
# User can have a *doubly-indirect* Role in an Account by virtue of being a
# member of a Group that has a Role in a Workspace in an Account.  Whew!
account_import_preserves_doubly_indirect_role: {
    ok 1, 'TEST: Preserves UGR/GWR/GARs (doubly-indirect)';
    my $account   = create_test_account_bypassing_factory();
    my $workspace = create_test_workspace(account => $account);
    my $group     = create_test_group();
    my $user      = create_test_user();

    # Add the User to the Account through a Group-in-Workspace membership.
    $workspace->add_group(group => $group);
    $group->add_user(user => $user);

    # Export and re-import the Account.
    export_and_reimport_account(
        account    => $account,
        workspaces => [$workspace],
        groups     => [$group],
        users      => [$user],
    );
}

###############################################################################
# TEST: preserve multiple indirect UARs
#
# User can have multiple *indirect* Roles in an Account through various means.
account_import_preserves_multiple_indirect_uars: {
    ok 1, 'TEST: Preserves multiple indirect UARs';
    my $account   = create_test_account_bypassing_factory();
    my $ws_one    = create_test_workspace(account => $account);
    my $ws_two    = create_test_workspace(account => $account);
    my $group_one = create_test_group();
    my $group_two = create_test_group();
    my $user      = create_test_user();

    # Indirect Role: User->Group->Account
    $account->add_group(group => $group_one);
    $group_one->add_user(user => $user);

    # Indirect Role: User->Workspace->Account
    $ws_one->add_user(user => $user);

    # Indirect Role: User->Group->Workspace->Account
    $ws_two->add_group(group => $group_two);
    $group_two->add_user(user => $user);

    # Export and re-import the Account.
    export_and_reimport_account(
        account    => $account,
        workspaces => [$ws_one, $ws_two],
        groups     => [$group_one, $group_two],
        users      => [$user],
    );
}

###############################################################################
# TEST: preserve multiple direct and indirect UARs
#
# User can have both a *direct* and an *indirect* Role in an Account.
account_import_preserves_direct_and_indirect_uars: {
    ok 1, 'TEST: Preserves direct and indirect UARs';
    my $account   = create_test_account_bypassing_factory();
    my $ws_one    = create_test_workspace(account => $account);
    my $ws_two    = create_test_workspace(account => $account);
    my $group_one = create_test_group();
    my $group_two = create_test_group();
    my $user      = create_test_user();

    # Direct Role: User->Account (as his Primary Account)
    $user->primary_account( $account );

    # Indirect Role: User->Group->Account
    $account->add_group(group => $group_one);
    $group_one->add_user(user => $user);

    # Indirect Role: User->Workspace->Account
    $ws_one->add_user(user => $user);

    # Indirect Role: User->Group->Workspace->Account
    $ws_two->add_group(group => $group_two);
    $group_two->add_user(user => $user);

    # Export and re-import the Account.
    export_and_reimport_account(
        account    => $account,
        workspaces => [$ws_one, $ws_two],
        groups     => [$group_one, $group_two],
        users      => [$user],
    );
}













###############################################################################
###############################################################################
### HELPER METHODS
###############################################################################
###############################################################################
sub _dump_gars {
    my $account = shift;
    my @gars;
    if ($account) {
        my $cursor  = $account->groups();
        while (my $group = $cursor->next) {
            push @gars, {
                group   => $group->driver_group_name,
                account => $account->name,
                role    => $account->role_for_group(group => $group)->name,
            };
        }
    }
    return @gars;
}

sub _dump_uars {
    my $account = shift;
    my @uars;
    if ($account) {
        my $cursor = $account->users();

        while (my $user = $cursor->next) {
            push @uars, {
                user    => $user->username,
                account => $account->name,
                role    => $account->role_for_user(user => $user)->name,
            };
        }
    }
    return @uars;
}

sub _dump_uwrs {
    my $workspace = shift;
    my @uwrs;
    if ($workspace) {
        my $cursor = $workspace->users();
        while (my $user = $cursor->next) {
            push @uwrs, {
                user      => $user->username,
                workspace => $workspace->name,
                role      => $workspace->role_for_user(user => $user)->name,
            };
        }
    }
    return @uwrs;
}

sub _dump_gwrs {
    my $workspace = shift;
    my @gwrs;
    if ($workspace) {
        my $cursor = $workspace->groups();
        while (my $group = $cursor->next) {
            push @gwrs, {
                group     => $group->driver_group_name,
                workspace => $workspace->name,
                role      => $workspace->role_for_group(group => $group)->name,
            };
        }
    }
    return @gwrs;
}

sub _dump_ugrs {
    my $group = shift;
    my @ugrs;
    if ($group) {
        my $cursor = $group->users();
        while (my $user = $cursor->next) {
            push @ugrs, {
                user  => $user->username,
                group => $group->driver_group_name,
                role  => $group->role_for_user(user => $user)->name,
            };
        }
    }
    return @ugrs;
}
