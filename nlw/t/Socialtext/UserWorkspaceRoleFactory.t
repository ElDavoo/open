#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use mocked 'Socialtext::Log', qw(:tests);
use Test::Socialtext tests => 40;
use Test::Exception;

###############################################################################
# Fixtures: db
# - need a DB, don't care what's in it
fixtures(qw( db ));

use_ok 'Socialtext::UserWorkspaceRoleFactory';

###############################################################################
# TEST: get a Factory instance
get_factory_instance: {
    # "new()" gets us a Factory
    my $instance_one = Socialtext::UserWorkspaceRoleFactory->new();
    isa_ok $instance_one, 'Socialtext::UserWorkspaceRoleFactory';

    # "instance()" gets us a Factory
    my $instance_two = Socialtext::UserWorkspaceRoleFactory->instance();
    isa_ok $instance_two, 'Socialtext::UserWorkspaceRoleFactory';

    # its the *same* Factory
    is $instance_one, $instance_two, '... and its the same Factory';
}

###############################################################################
# TEST: create a new UWR, retrieve from DB
create_uwr: {
    my $user      = create_test_user();
    my $workspace = create_test_workspace();
    my $role      = Socialtext::Role->new(name => 'guest');

    # create the UWR, make sure it got created with our info
    clear_log();
    my $uwr   = Socialtext::UserWorkspaceRoleFactory->Create( {
        user_id      => $user->user_id,
        workspace_id => $workspace->workspace_id,
        role_id      => $role->role_id,
    } );
    isa_ok $uwr, 'Socialtext::UserWorkspaceRole', 'created UWR';
    is $uwr->user_id,  $user->user_id,
        '... with provided user_id';
    is $uwr->workspace_id, $workspace->workspace_id,
        '... with provided workspace_id';
    is $uwr->role_id,  $role->role_id,
        '... with provided role_id';

    # and that an entry was logged
    logged_like 'info', qr/ASSIGN,USER_ROLE/, '... creation was logged';

    # double-check that we can pull this UWR from the DB
    my $queried = Socialtext::UserWorkspaceRoleFactory->Get(
        user_id      => $user->user_id,
        workspace_id => $workspace->workspace_id,
    );
    isa_ok $queried, 'Socialtext::UserWorkspaceRole', 'queried UWR';
    is $queried->user_id,  $user->user_id,
        '... with expected user_id';
    is $queried->workspace_id, $workspace->workspace_id,
        '... with expected workspace_id';
    is $queried->role_id,  $role->role_id,
        '... with expected role_id';
}

###############################################################################
# TEST: create UWR with additional attributes
create_uwr_with_additional_attributes: {
    my $user      = create_test_user();
    my $workspace = create_test_workspace();
    my $role      = Socialtext::Role->new(name => 'guest');

    # UWR gets created, and we don't die a horrible death due to unknown extra
    # additional attributes
    my $uwr;
    lives_ok sub {
        $uwr   = Socialtext::UserWorkspaceRoleFactory->Create( {
            user_id      => $user->user_id,
            workspace_id => $workspace->workspace_id,
            role_id      => $role->role_id,
            bogus        => 'attribute',
        } );
    }, 'created UWR when additional attributes provided';
    isa_ok $uwr, 'Socialtext::UserWorkspaceRole', '... created UWR';
}

###############################################################################
# TEST: create a duplicate UWR
create_duplicate_uwr: {
    my $user      = create_test_user();
    my $workspace = create_test_workspace();
    my $role      = Socialtext::Role->new(name => 'guest');

    # create the UWR
    my $uwr   = Socialtext::UserWorkspaceRoleFactory->Create( {
        user_id      => $user->user_id,
        workspace_id => $workspace->workspace_id,
        role_id      => $role->role_id,
    } );
    isa_ok $uwr, 'Socialtext::UserWorkspaceRole', 'created UWR';

    # create a duplicate UWR
    dies_ok {
        my $dupe = Socialtext::UserWorkspaceRoleFactory->Create( {
            user_id      => $user->user_id,
            workspace_id => $workspace->workspace_id,
            role_id      => $role->role_id,
        } );
    } 'creating a duplicate record dies.';
}

###############################################################################
# TEST: update a UWR
update_a_uwr: {
    my $user        = create_test_user();
    my $workspace   = create_test_workspace();
    my $member_role = Socialtext::Role->new(name => 'member');
    my $guest_role  = Socialtext::Role->new(name => 'guest');
    my $factory     = Socialtext::UserWorkspaceRoleFactory->instance();

    # create the UWR
    my $uwr   = $factory->Create( {
        user_id      => $user->user_id,
        workspace_id => $workspace->workspace_id,
        role_id      => $member_role->role_id,
    } );
    isa_ok $uwr, 'Socialtext::UserWorkspaceRole', 'created UWR';

    # update the UWR
    clear_log();
    my $rc = $factory->Update($uwr, { role_id => $guest_role->role_id } );
    ok $rc, 'updated UWR';
    is $uwr->role_id, $guest_role->role_id, '... with updated role_id';

    # and that an entry was logged
    logged_like 'info', qr/CHANGE,USER_ROLE/, '... update was logged';

    # make sure the updates are reflected in the DB
    my $queried = $factory->Get(
        user_id      => $user->user_id,
        workspace_id => $workspace->workspace_id,
    );
    is $queried->role_id, $guest_role->role_id, '... which is reflected in DB';
}

###############################################################################
# TEST: ignores updates to "user_id" primary key
ignore_update_to_user_id_pkey: {
    my $user_one    = create_test_user();
    my $user_two    = create_test_user();
    my $workspace   = create_test_workspace();
    my $member_role = Socialtext::Role->new(name => 'member');
    my $factory     = Socialtext::UserWorkspaceRoleFactory->instance();

    # create the UWR
    my $uwr   = $factory->Create( {
        user_id      => $user_one->user_id,
        workspace_id => $workspace->workspace_id,
        role_id      => $member_role->role_id,
    } );
    isa_ok $uwr, 'Socialtext::UserWorkspaceRole', 'created UWR';

    # update the UWR
    clear_log();
    my $rc = $factory->Update($uwr, { user_id => $user_two->user_id } );
    ok $rc, 'updated UWR';
    is $uwr->user_id, $user_one->user_id, '... UWR has original user_id';

    # and that *NO* entry was logged
    logged_not_like 'info', qr/USER_ROLE/, '... NO update was logged';
}

###############################################################################
# TEST: ignores updates to "workspace_id" primary key
ignore_update_to_workspace_id_pkey: {
    my $user          = create_test_user();
    my $workspace_one = create_test_workspace();
    my $workspace_two = create_test_workspace();
    my $member_role   = Socialtext::Role->new(name => 'member');
    my $factory       = Socialtext::UserWorkspaceRoleFactory->instance();

    # create the UWR
    my $uwr   = $factory->Create( {
        user_id      => $user->user_id,
        workspace_id => $workspace_one->workspace_id,
        role_id      => $member_role->role_id,
    } );
    isa_ok $uwr, 'Socialtext::UserWorkspaceRole', 'created UWR';

    # update the UWR
    clear_log();
    my $rc = $factory->Update($uwr, 
        { workspace_id => $workspace_two->workspace_id } );
    ok $rc, 'updated UWR';
    is $uwr->workspace_id, $workspace_one->workspace_id,
        '... UWR has original workspace_id';

    # and that *NO* entry was logged
    logged_not_like 'info', qr/USER_ROLE/, '... NO update was logged';
}

###############################################################################
# TEST: update a non-existing UWR
update_non_existing_uwr: {
    my $uwr = Socialtext::UserWorkspaceRole->new( {
        user_id      => 987654321,
        workspace_id => 987654321,
        role_id      => 987654321,
    } );
    isa_ok $uwr, 'Socialtext::UserWorkspaceRole';

    # Updating a non-existing UWR fails silently; it *looks like* it was ok,
    # but nothing actually got updated in the DB.
    #
    # This mimics the behaviour of ST::User and for ST::UserWorkspaceRole.
    clear_log();
    lives_ok {
        Socialtext::UserWorkspaceRoleFactory->Update(
            $uwr,
            { role_id => '1234' },
        );
    } 'updating an non-existing UWR lives (but updates nothing)';

    # and that *NO* entry was logged
    logged_not_like 'info', qr/USER_ROLE/, '... NO update was logged';
}

###############################################################################
# TEST: delete an UWR
delete_uwr: {
    my $user        = create_test_user();
    my $workspace   = create_test_workspace();
    my $member_role = Socialtext::Role->new(name => 'member');
    my $factory     = Socialtext::UserWorkspaceRoleFactory->instance();

    # create the UWR
    my $uwr   = $factory->Create( {
        user_id      => $user->user_id,
        workspace_id => $workspace->workspace_id,
        role_id      => $member_role->role_id,
    } );
    isa_ok $uwr, 'Socialtext::UserWorkspaceRole', 'created UWR';

    # delete the UWR
    clear_log();
    my $rc = $factory->Delete($uwr);
    ok $rc, 'deleted the UWR';


    # and that an entry was logged
    logged_like 'info', qr/REMOVE,USER_ROLE/, '... removal was logged';

    # make sure the delete was reflected in the DB
    my $queried = $factory->Get(
        user_id      => $user->user_id,
        workspace_id => $workspace->workspace_id,
    );
    ok !$queried, '... which is reflected in DB';
}

###############################################################################
# TEST: delete a non-existing UWR
delete_non_existing_uwr: {
    my $uwr = Socialtext::UserWorkspaceRole->new( {
        user_id      => 987654321,
        workspace_id => 987654321,
        role_id      => 987654321,
        } );
    isa_ok $uwr, 'Socialtext::UserWorkspaceRole';

    # Deleting a non-existing UWR fails, without throwing an exception
    clear_log();
    my $factory = Socialtext::UserWorkspaceRoleFactory->instance();
    my $rc      = $factory->Delete($uwr);
    ok !$rc, 'cannot delete a non-existing UWR';

    # and that *NO* entry was logged
    logged_not_like 'info', qr/USER_ROLE/, '... NO removal was logged';
}

