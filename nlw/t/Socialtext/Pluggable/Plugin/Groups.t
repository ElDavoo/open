#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::Socialtext tests => 57;
use Test::Exception;
use Test::Socialtext::Account;
use Test::Socialtext::User;
use Test::Output;
use Socialtext::UserGroupRoleFactory;
use Socialtext::Role;
use File::Temp qw/tempdir/;
use YAML qw/LoadFile/;

use_ok 'Socialtext::Pluggable::Plugin::Groups';

###############################################################################
# Fixtures: db
# - we need a DB, but don't care what's in it.
fixtures(qw/db/);

################################################################################
# TEST: backup
backup: {
    my $data_ref = {};
    my $def_user = Socialtext::User->SystemUser;
    my $ugr_role = Socialtext::UserGroupRoleFactory->DefaultRole();
    my $gwr_role = Socialtext::GroupWorkspaceRoleFactory->DefaultRole();

    # create dummy data.
    my $account   = create_test_account_bypassing_factory();
    my $group_one = create_test_group(account => $account);
    my $user_one  = create_test_user();
    add_user_to_group($user_one, $group_one);

    # this group will _not_ be in the backup; it's not in the account.
    my $group_two    = create_test_group();
    add_user_to_group( $user_one, $group_two);

    # this Group will be in the backups (Account, and Workspace)
    my $user_two    = create_test_user();
    my $group_three = create_test_group(account => $account);
    $group_three->add_user(user => $user_two);

    my $user_three    = create_test_user();
    $group_three->add_user(user => $user_three);

    # Load some users into the workspace (direct & transitive)
    my $ws = create_test_workspace(account => $account);
    $ws->add_group( group => $group_three, role => Socialtext::Role->WorkspaceAdmin() );
    $ws->add_user(user => $user_one);
    $ws->add_user(user => $user_three);

    # make Account backup data
    my $plugin = Socialtext::Pluggable::Plugin::Groups->new();
    stdout_is {
        $plugin->export_groups_for_account($account, $data_ref);
    } "Exporting all groups for account '".$account->name."'...\n";

    my $expected = [
        {
            'driver_group_name'   => $group_one->driver_group_name,
            'created_by_username' => $def_user->username,
            'users'               => [
                {
                    'role_name' => $ugr_role->name,
                    'username'  => $user_one->username,
                }
            ],
        },
        {
            driver_group_name   => $group_three->driver_group_name,
            created_by_username => $def_user->username,
            users               => [
                {
                    username  => $user_two->username,
                    role_name => $ugr_role->name,
                },
                {
                    username  => $user_three->username,
                    role_name => $ugr_role->name,
                },
            ],
        }
    ];
    is_deeply $data_ref->{groups}, $expected, 'correct export data structure';

    # Make Workspace backup data
    $data_ref = {};
    stdout_is {
        $plugin->export_groups_for_workspace($ws, $data_ref);
    } "Exporting all groups for workspace '" . $ws->name . "'...\n";
    $expected = [
        {
            driver_group_name   => $group_three->driver_group_name,
            created_by_username => $def_user->username,
            role_name           => 'workspace_admin',
            users               => [
                {
                    username  => $user_two->username,
                    role_name => $ugr_role->name,
                },
                {
                    username  => $user_three->username,
                    role_name => $ugr_role->name,
                },
            ],
        }
    ];
    is_deeply $data_ref->{groups}, $expected, 'correct WS export data structure';

    direct_workspace_roles_exported: {
        my $dir = tempdir(CLEANUP => 1);
        $ws->_dump_users_to_yaml_file($dir, 'exported');
        my $dumped = LoadFile("$dir/exported-users.yaml");

        is scalar(@$dumped), 3, 'got two dumped users';

        is $dumped->[0]{username}, $user_one->username, 'correct username';
        is $dumped->[0]{role_name}, $ugr_role->name, 'correct role';

        is $dumped->[1]{username}, $user_three->username, 'correct username';
        is $dumped->[1]{role_name}, $ugr_role->name, 'correct direct role';
        ok !exists($dumped->[1]{indirect}), 'role is via some group somewhere';

        is $dumped->[2]{username}, $user_two->username, 'correct username';
        is $dumped->[2]{role_name}, 'member', 'correct role via group';
        is $dumped->[2]{indirect}, 1, 'role is via some group somewhere';
    }
}

################################################################################
# TEST: restore
basic_restore: {
    my $data_ref = {};
    my ($test_username, $test_creator_name, $test_group_name, $test_role_name);

    do_backup: {
        my $account = create_test_account_bypassing_factory();
        my $user    = create_test_user();
        my $group   = create_test_group(account => $account);
        add_user_to_group($user, $group);

        # hold onto the User's name, so we can check for it later after import
        $test_username     = $user->username();
        $test_creator_name = $group->creator->username();
        $test_group_name   = $group->driver_group_name();
        $test_role_name = Socialtext::UserGroupRoleFactory->Get(
            user_id  => $user->user_id(),
            group_id => $group->group_id(),
        )->role->name();

        # make backup data
        my $plugin = Socialtext::Pluggable::Plugin::Groups->new();
        stdout_is {
            $plugin->export_groups_for_account($account, $data_ref);
        } "Exporting all groups for account '".$account->name."'...\n";

        ### CLEANUP: nuke stuff in DB before we import
        ### - we can't nuke the User; the Account import is responsible for
        ###   re-creating the User, not the Groups import
        $group->delete();
        Test::Socialtext::Account->delete_recklessly( $account );

        # SANITY CHECK: Group/Account should *NOT* be in the DB any more
        $group = Socialtext::Group->GetGroup(group_id => $group->group_id);
        $account
            = Socialtext::Account->new(account_id => $account->account_id);

        ok !$group,   '... group has been deleted';
        ok !$account, '... account has been deleted';
    }

    # import the data that we just exported
    my $plugin  = Socialtext::Pluggable::Plugin::Groups->new();
    my $account = create_test_account_bypassing_factory();
    stdout_is {
        $plugin->import_groups_for_account($account, $data_ref);
    } "Importing all groups for account '".$account->name."'...\n";

    my $groups = $account->groups;
    is $groups->count, 1, 'got a group';

    # Test group
    my $group = $groups->next;
    is $group->primary_account_id, $account->account_id,
        '... with correct primary account_id';
    is $group->driver_group_name, $test_group_name,
        '... with correct driver_group_name';

    # make sure that the creator exists
    my $creator = $group->creator;
    isa_ok $creator, 'Socialtext::User', '... creator';
    is $creator->username, $test_creator_name, '... ... correct creating User';
    
    # Test users
    my $users = $group->users;
    is $users->count, 1, 'got a user';
    
    my $user = $users->next;
    isa_ok $user, 'Socialtext::User', '... member User';
    is $user->username, $test_username, '... ... is test User';

    # User has the correct Role in the Group
    my $ugr = Socialtext::UserGroupRoleFactory->Get(
        user_id  => $user->user_id,
        group_id => $group->group_id,
    );
    is $ugr->role->name(), $test_role_name, '... correct Role in Group';
}

################################################################################
# TEST: restore, pre-groups
restore_no_groups: {
    my $data_ref = {};
    my $account  = create_test_account_bypassing_factory();
    my $plugin   = Socialtext::Pluggable::Plugin::Groups->new();

    lives_ok { 
        stdout_is {
            $plugin->import_groups_for_account($account, $data_ref);
        } "";
    } 'import with no groups data lives';

    is $account->groups->count, 0, '... and no groups are imported';
}

################################################################################
# TEST: restore when the Group already exists
restore_with_existing_group: {
    my $data_ref = {};
    my $test_group_name;
    my ($test_user_one, $test_role_id_one);
    my ($test_user_two, $test_role_id_two);
    my $default_ugr_role_id = Socialtext::UserGroupRoleFactory->DefaultRoleId;

    do_backup: {
        # create a Group to test with
        my $account  = create_test_account_bypassing_factory();
        my $group    = create_test_group(account => $account);
        $test_group_name = $group->driver_group_name;

        # add two Users to the Group, neither of which has the Default Role
        # (so we can check that the Role was set properly).  We honestly don't
        # care what Role it is, only that its not the Default Role.
        $test_user_one    = create_test_user();
        $test_role_id_one =
            Socialtext::Role->new(name => 'guest')->role_id;
        Socialtext::UserGroupRoleFactory->Create( {
            group_id => $group->group_id,
            user_id  => $test_user_one->user_id,
            role_id  => $test_role_id_one,
        } );
        isnt $test_role_id_one, $default_ugr_role_id,
            'test Role is *not* the Default UGR Role';

        $test_user_two    = create_test_user();
        $test_role_id_two =
            Socialtext::Role->new(name => 'impersonator')->role_id;
        Socialtext::UserGroupRoleFactory->Create( {
            group_id => $group->group_id,
            user_id  => $test_user_two->user_id,
            role_id  => $test_role_id_two,
        } );
        isnt $test_role_id_two, $default_ugr_role_id,
            'test Role is *not* the Default UGR Role';

        # make backup data
        my $plugin = Socialtext::Pluggable::Plugin::Groups->new();
        stdout_is {
            $plugin->export_groups_for_account($account, $data_ref);
        } "Exporting all groups for account '".$account->name."'...\n";

        ### CLEANUP: nuke stuff in DB before we import
        ### - don't nuke the Users, though; the Account import is responsible
        ###   for setting that up _before_ we import Group data
        $group->delete();
        Test::Socialtext::Account->delete_recklessly($account);

        # SANITY CHECK: Group/Account should *NOT* be in the DB any more
        $group = Socialtext::Group->GetGroup(group_id => $group->group_id);
        $account
            = Socialtext::Account->new(account_id => $account->account_id);

        ok !$group,   '... group has been deleted';
        ok !$account, '... account has been deleted';
    }

    # create an Account and then re-create the Group, so we can test import
    # *merging*
    my $account = create_test_account_bypassing_factory();
    my $group   = create_test_group(
        account   => $account,
        unique_id => $test_group_name
    );

    # add one of the Users into the Group, but with a *different* Role than
    # they were exported with (so we can verify that it doesn't get
    # over-written).
    my $new_role = Socialtext::Role->new(name => 'authenticated_user');
    isnt $new_role->role_id, $test_role_id_one,
        'new Role is *not* the Role the User was exported with';
    Socialtext::UserGroupRoleFactory->Create( {
        user_id  => $test_user_one->user_id,
        group_id => $group->group_id,
        role_id  => $new_role->role_id,
    } );

    # import the data that we just exported
    my $plugin = Socialtext::Pluggable::Plugin::Groups->new();
    stdout_is {
        $plugin->import_groups_for_account($account, $data_ref);
    } "Importing all groups for account '".$account->name."'...\n";

    # CHECK: the User we'd added to the Group already has his Role untouched
    my $ugr = Socialtext::UserGroupRoleFactory->Get(
        user_id  => $test_user_one->user_id,
        group_id => $group->group_id,
    );
    is $ugr->role_id, $new_role->role_id,
        '... existing User had their UGR left as-is';

    # CHECK: the other User was added to the Group, with his original Role
    $ugr = Socialtext::UserGroupRoleFactory->Get(
        user_id  => $test_user_two->user_id,
        group_id => $group->group_id,
    );
    is $ugr->role_id, $test_role_id_two,
        '... missing User was added with their exported Role';
}

###############################################################################
# TEST: basic restore of Workspace
restore_workspace: {
    my $test_user = create_test_user();
    my $data_ref = {
        groups => [ {
            driver_group_name   => 'Test Group Name',
            created_by_username => 'system-user',
            role_name           => 'guest',             # not the default Role
            users => [
                {
                    username    => $test_user->username,
                    role_name   => 'impersonator',
                },
            ],
        } ],
    };

    # NOTE: Its *ok* to leave our $test_user in the system; on restore we
    # rely on ST::WS::Importer to create the User record for us.

    # Import the Workspace
    my $plugin = Socialtext::Pluggable::Plugin::Groups->new();
    my $ws     = create_test_workspace();
    stdout_is {
        $plugin->import_groups_for_workspace($ws, $data_ref);
    } "Importing all groups for workspace '".$ws->name."'...\n";

    # Make sure that the Group got added to the WS
    my $groups = $ws->groups;
    is $groups->count, 1, 'got a group';

    my $group = $groups->next;
    is $group->driver_group_name, 'Test Group Name',
        '... with correct driver_group_name';

    my $creator = $group->creator;
    isa_ok $creator, 'Socialtext::User', '... creator';
    is $creator->username, 'system-user', '... ... correct creating user';

    my $gwr = $ws->role_for_group($group);
    is $gwr->name, 'guest', '... correct GWR';

    my $users = $group->users;
    is $users->count, 1, '... contains a User';

    my $user = $users->next;
    is $user->username, $test_user->username,
        '... ... correct User';

    my $uwr = $group->role_for_user($user);
    is $uwr->name, 'impersonator', '... correct UWR';
}

###############################################################################
# TEST: restore of Workspace, when Group already exists in the Account
restore_workspace_with_existing_group: {
    my $account    = create_test_account_bypassing_factory();
    my $test_user  = create_test_user();
    my $group_name = 'Another Test Group';
    my $data_ref = {
        groups => [ {
            driver_group_name   => $group_name,
            created_by_username => 'carl',              # non-existent User
            role_name           => 'guest',             # not the default Role
            users => [
                {
                    username    => $test_user->username,
                    role_name   => 'impersonator',
                },
            ],
        } ],
    };

    # NOTE: Its *ok* to leave our $test_user in the system; on restore we
    # rely on ST::WS::Importer to create the User record for us.

    # Create the Group in the Account, so it already exists
    {
        my $group = create_test_group(
            unique_id => $group_name,
            account   => $account,
        );
        is $group->users->count(), 0, 'Group has *no* Users in it (yet)';
    }

    # Import the Workspace
    my $plugin = Socialtext::Pluggable::Plugin::Groups->new();
    my $ws     = create_test_workspace();
    stdout_is {
        $plugin->import_groups_for_workspace($ws, $data_ref);
    } "Importing all groups for workspace '".$ws->name."'...\n";

    # Grab the Group, make sure we didn't create it all over again
    my $groups = $ws->groups;
    is $groups->count, 1, 'got a group';

    my $group = $groups->next;
    is $group->driver_group_name, $group_name,
        '... with correct driver_group_name';

    my $creator = $group->creator;
    isnt $creator->username, 'carl', '... did not override creating user';

    my $gwr = $ws->role_for_group($group);
    is $gwr->name, 'guest', '... correct GWR';

    my $users = $group->users;
    is $users->count, 1, '... now contains a User';

    my $user = $users->next;
    is $user->username, $test_user->username,
        '... ... correct User';

    my $uwr = $group->role_for_user($user);
    is $uwr->name, 'impersonator', '... correct UWR';
}

###############################################################################
# Helper method, to add a User to a Group.
sub add_user_to_group {
    my $user  = shift;
    my $group = shift;

    Socialtext::UserGroupRoleFactory->Create({
        user_id  => $user->user_id, 
        group_id => $group->group_id,
    });
}
