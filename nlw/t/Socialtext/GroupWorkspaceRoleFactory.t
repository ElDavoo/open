#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
# use mocked 'Socialtext::Events', qw(clear_events event_ok is_event_count);
use mocked 'Socialtext::Log', qw(:tests);
use Test::Socialtext tests => 163;
use Test::Exception;

###############################################################################
# Fixtures: db
# - need a DB, don't care what's in it
fixtures(qw( db ));

use_ok 'Socialtext::GroupWorkspaceRoleFactory';

###############################################################################
# TEST: get a Factory instance
get_factory_instance: {
    # "new()" gets us a Factory
    my $instance_one = Socialtext::GroupWorkspaceRoleFactory->new();
    isa_ok $instance_one, 'Socialtext::GroupWorkspaceRoleFactory';

    # "instance()" gets us a Factory
    my $instance_two = Socialtext::GroupWorkspaceRoleFactory->instance();
    isa_ok $instance_two, 'Socialtext::GroupWorkspaceRoleFactory';

    # its the *same* Factory
    is $instance_one, $instance_two, '... and its the same Factory';
}

###############################################################################
# TEST: SortedResultSet default order 
sorted_result_set_default_order: {
    # Default is group_id, or the order they were created.
    my $group1 = create_test_group();
    my $group2 = create_test_group();
    my $wksp   = create_test_workspace();

    $wksp->add_group( group => $group1 );
    ok $wksp->has_group( $group1 ), 'Group1 is in Workspace';

    $wksp->add_group( group => $group2 );
    ok $wksp->has_group( $group2 ), 'Group2 is in Workspace';

    default_sort_order: {
        my $gwrs = Socialtext::GroupWorkspaceRoleFactory->SortedResultSet(
            workspace_id => $wksp->workspace_id,
        );
        isa_ok $gwrs, 'Socialtext::MultiCursor', 'Got a multicursor';
        is $gwrs->count, '2', '... with 2 GWRs';

        my $gwr = $gwrs->next();
        is $gwr->group_id, $group1->group_id, '... with Group 1 first';

        $gwr = $gwrs->next();
        is $gwr->group_id, $group2->group_id, '... with Group 2 second';
    }

    asc_sort_order: {
        my $gwrs = Socialtext::GroupWorkspaceRoleFactory->SortedResultSet(
            sort_order   => 'asc',
            workspace_id => $wksp->workspace_id,
        );
        isa_ok $gwrs, 'Socialtext::MultiCursor', 'Got a multicursor';
        is $gwrs->count, '2', '... with 2 GWRs';

        my $gwr = $gwrs->next();
        is $gwr->group_id, $group1->group_id, '... with Group 1 first';

        $gwr = $gwrs->next();
        is $gwr->group_id, $group2->group_id, '... with Group 2 second';
    }

    desc_sort_order: {
        my $gwrs = Socialtext::GroupWorkspaceRoleFactory->SortedResultSet(
            sort_order   => 'desc',
            workspace_id => $wksp->workspace_id,
        );
        isa_ok $gwrs, 'Socialtext::MultiCursor', 'Got a multicursor';
        is $gwrs->count, '2', '... with 2 GWRs';

        my $gwr = $gwrs->next();
        is $gwr->group_id, $group2->group_id, '... with Group 2 first';

        $gwr = $gwrs->next();
        is $gwr->group_id, $group1->group_id, '... with Group 1 second';
    }
}

###############################################################################
# TEST: SortedResultSet 'name' order 
sorted_result_set_name_order: {
    # Default is group_id, or the order they were created.
    my $group  = create_test_group();
    my $wksp_a = create_test_workspace( unique_id => 'aaa' );
    my $wksp_z = create_test_workspace( unique_id => 'zzz' );

    $wksp_a->add_group( group => $group );
    ok $wksp_a->has_group( $group ), 'Group is in Workspace A';

    $wksp_z->add_group( group => $group );
    ok $wksp_z->has_group( $group ), 'Group is in Workspace Z';

    default_sort_order: {
        my $gwrs = Socialtext::GroupWorkspaceRoleFactory->SortedResultSet(
            order_by => 'name',
            group_id => $group->group_id,
        );

        isa_ok $gwrs, 'Socialtext::MultiCursor', 'Got a multicursor';
        is $gwrs->count, '2', '... with 2 GWRs';

        my $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_a->workspace_id,
            '... with Workspace A first';

        $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_z->workspace_id,
            '... with Workspace Z second';
    }

    asc_sort_order: {
        my $gwrs = Socialtext::GroupWorkspaceRoleFactory->SortedResultSet(
            order_by   => 'name',
            sort_order => 'asc',
            group_id   => $group->group_id,
        );

        isa_ok $gwrs, 'Socialtext::MultiCursor', 'Got a multicursor';
        is $gwrs->count, '2', '... with 2 GWRs';

        my $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_a->workspace_id,
            '... with Workspace A first';

        $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_z->workspace_id,
            '... with Workspace Z second';
    }

    desc_sort_order: {
        my $gwrs = Socialtext::GroupWorkspaceRoleFactory->SortedResultSet(
            order_by   => 'name',
            sort_order => 'desc',
            group_id   => $group->group_id,
        );

        isa_ok $gwrs, 'Socialtext::MultiCursor', 'Got a multicursor';
        is $gwrs->count, '2', '... with 2 GWRs';

        my $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_z->workspace_id,
            '... with Workspace Z first';

        $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_a->workspace_id,
            '... with Workspace A second';
    }
}

###############################################################################
# TEST: SortedResultSet 'account_name' order 
sorted_result_set_account_name_order: {
    my $acct_a = create_test_account_bypassing_factory( 'AA' );
    my $acct_b = create_test_account_bypassing_factory( 'BB' );
    my $wksp_1 = create_test_workspace( account => $acct_a );
    my $wksp_2 = create_test_workspace( account => $acct_b );
    my $group  = create_test_group();

    $wksp_1->add_group( group => $group );
    ok $wksp_1->has_group( $group ), 'Group is in Workspace 1';

    $wksp_2->add_group( group => $group );
    ok $wksp_2->has_group( $group ), 'Group is in Workspace 2';

    default_sort_order: {
        my $gwrs = Socialtext::GroupWorkspaceRoleFactory->SortedResultSet(
            order_by => 'account_name',
            group_id => $group->group_id,
        );

        isa_ok $gwrs, 'Socialtext::MultiCursor', 'Got a multicursor';
        is $gwrs->count, '2', '... with 2 GWRs';

        my $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_1->workspace_id,
            '... with Workspace 1 first';

        $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_2->workspace_id,
            '... with Workspace 2 second';
    }

    asc_sort_order: {
        my $gwrs = Socialtext::GroupWorkspaceRoleFactory->SortedResultSet(
            sort_order => 'asc',
            order_by   => 'account_name',
            group_id   => $group->group_id,
        );

        isa_ok $gwrs, 'Socialtext::MultiCursor', 'Got a multicursor';
        is $gwrs->count, '2', '... with 2 GWRs';

        my $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_1->workspace_id,
            '... with Workspace 1 first';

        $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_2->workspace_id,
            '... with Workspace 2 second';
    }

    desc_sort_order: {
        my $gwrs = Socialtext::GroupWorkspaceRoleFactory->SortedResultSet(
            sort_order => 'desc',
            order_by   => 'account_name',
            group_id   => $group->group_id,
        );

        isa_ok $gwrs, 'Socialtext::MultiCursor', 'Got a multicursor';
        is $gwrs->count, '2', '... with 2 GWRs';

        my $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_2->workspace_id,
            '... with Workspace 2 first';

        $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_1->workspace_id,
            '... with Workspace 1 second';
    }
}

###############################################################################
# TEST: SortedResultSet 'creation_datetime' order 
sorted_result_set_creation_datetime_order: {
    my $wksp_1 = create_test_workspace();
    sleep 1;  # be _sure_ create times will be different.
    my $wksp_2 = create_test_workspace();
    my $group  = create_test_group();

    $wksp_1->add_group( group => $group );
    ok $wksp_1->has_group( $group ), 'Group is in Workspace 1';

    $wksp_2->add_group( group => $group );
    ok $wksp_2->has_group( $group ), 'Group is in Workspace 2';

    default_sort_order: {
        my $gwrs = Socialtext::GroupWorkspaceRoleFactory->SortedResultSet(
            order_by => 'creation_datetime',
            group_id => $group->group_id,
        );

        isa_ok $gwrs, 'Socialtext::MultiCursor', 'Got a multicursor';
        is $gwrs->count, '2', '... with 2 GWRs';

        my $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_1->workspace_id,
            '... with Workspace 1 first';

        $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_2->workspace_id,
            '... with Workspace 2 second';
    }

    asc_sort_order: {
        my $gwrs = Socialtext::GroupWorkspaceRoleFactory->SortedResultSet(
            sort_order => 'asc',
            order_by   => 'creation_datetime',
            group_id   => $group->group_id,
        );

        isa_ok $gwrs, 'Socialtext::MultiCursor', 'Got a multicursor';
        is $gwrs->count, '2', '... with 2 GWRs';

        my $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_1->workspace_id,
            '... with Workspace 1 first';

        $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_2->workspace_id,
            '... with Workspace 2 second';
    }

    desc_sort_order: {
        my $gwrs = Socialtext::GroupWorkspaceRoleFactory->SortedResultSet(
            sort_order => 'desc',
            order_by   => 'creation_datetime',
            group_id   => $group->group_id,
        );

        isa_ok $gwrs, 'Socialtext::MultiCursor', 'Got a multicursor';
        is $gwrs->count, '2', '... with 2 GWRs';

        my $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_2->workspace_id,
            '... with Workspace 2 first';

        $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_1->workspace_id,
            '... with Workspace 1 second';
    }
}

###############################################################################
# TEST: SortedResultSet 'creator' order 
sorted_result_set_creator: {
    my $user_a = create_test_user( unique_id => 'a' );
    my $user_b = create_test_user( unique_id => 'b' );
    my $wksp_1 = create_test_workspace( user => $user_a );
    my $wksp_2 = create_test_workspace( user => $user_b );
    my $group  = create_test_group();

    $wksp_1->add_group( group => $group );
    ok $wksp_1->has_group( $group ), 'Group is in Workspace 1';

    $wksp_2->add_group( group => $group );
    ok $wksp_2->has_group( $group ), 'Group is in Workspace 2';

    default_sort_order: {
        my $gwrs = Socialtext::GroupWorkspaceRoleFactory->SortedResultSet(
            order_by => 'creator',
            group_id => $group->group_id,
        );

        isa_ok $gwrs, 'Socialtext::MultiCursor', 'Got a multicursor';
        is $gwrs->count, '2', '... with 2 GWRs';

        my $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_1->workspace_id,
            '... with Workspace 1 first';

        $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_2->workspace_id,
            '... with Workspace 2 second';
    }

    asc_sort_order: {
        my $gwrs = Socialtext::GroupWorkspaceRoleFactory->SortedResultSet(
            sort_order => 'asc',
            order_by   => 'creator',
            group_id   => $group->group_id,
        );

        isa_ok $gwrs, 'Socialtext::MultiCursor', 'Got a multicursor';
        is $gwrs->count, '2', '... with 2 GWRs';

        my $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_1->workspace_id,
            '... with Workspace 1 first';

        $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_2->workspace_id,
            '... with Workspace 2 second';
    }

    desc_sort_order: {
        my $gwrs = Socialtext::GroupWorkspaceRoleFactory->SortedResultSet(
            sort_order => 'desc',
            order_by   => 'creator',
            group_id   => $group->group_id,
        );

        isa_ok $gwrs, 'Socialtext::MultiCursor', 'Got a multicursor';
        is $gwrs->count, '2', '... with 2 GWRs';

        my $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_2->workspace_id,
            '... with Workspace 2 first';

        $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_1->workspace_id,
            '... with Workspace 1 second';
    }
}
###############################################################################
# TEST: SortedResultSet 'user_count' order 
sorted_result_set_user_count_order: {
    my $group  = create_test_group();
    my $wksp_a = create_test_workspace();
    my $wksp_b = create_test_workspace();
    my $user_1 = create_test_user();
    my $user_2 = create_test_user();

    # Workspace A has one user
    $wksp_a->add_group( group => $group );
    ok $wksp_a->has_group( $group ), 'Group is in Workspace A';
    $wksp_a->add_user( user => $user_1 );
    ok $wksp_a->has_user( $user_1 ), 'User 1 is in Workspace A';

    # Workspace B has two users
    $wksp_b->add_group( group => $group );
    ok $wksp_b->has_group( $group ), 'Group is in Workspace B';
    $wksp_b->add_user( user => $user_1 );
    ok $wksp_b->has_user( $user_1 ), 'User 1 is in Workspace B';
    $wksp_b->add_user( user => $user_2 );
    ok $wksp_b->has_user( $user_2 ), 'User 2 is in Workspace B';

    default_sort_order: {
        my $gwrs = Socialtext::GroupWorkspaceRoleFactory->SortedResultSet(
            order_by => 'user_count',
            group_id => $group->group_id,
        );

        isa_ok $gwrs, 'Socialtext::MultiCursor', 'Got a multicursor';
        is $gwrs->count, '2', '... with 2 GWRs';

        my $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_a->workspace_id,
            '... with Workspace A first';
        is $gwr->workspace->user_count(), '1',
            '.... ... with 1 user';

        $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_b->workspace_id,
            '... with Workspace B second';
        is $gwr->workspace->user_count(), '2',
            '.... ... with 2 users';
    }

    asc_sort_order: {
        my $gwrs = Socialtext::GroupWorkspaceRoleFactory->SortedResultSet(
            sort_order => 'asc',
            order_by   => 'user_count',
            group_id   => $group->group_id,
        );

        isa_ok $gwrs, 'Socialtext::MultiCursor', 'Got a multicursor';
        is $gwrs->count, '2', '... with 2 GWRs';

        my $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_a->workspace_id,
            '... with Workspace A first';
        is $gwr->workspace->user_count(), '1',
            '.... ... with 1 user';

        $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_b->workspace_id,
            '... with Workspace B second';
        is $gwr->workspace->user_count(), '2',
            '.... ... with 2 users';
    }

    desc_sort_order: {
        my $gwrs = Socialtext::GroupWorkspaceRoleFactory->SortedResultSet(
            sort_order => 'desc',
            order_by   => 'user_count',
            group_id   => $group->group_id,
        );

        isa_ok $gwrs, 'Socialtext::MultiCursor', 'Got a multicursor';
        is $gwrs->count, '2', '... with 2 GWRs';

        my $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_b->workspace_id,
            '... with Workspace B first';
        is $gwr->workspace->user_count(), '2',
            '.... ... with 2 user';

        $gwr = $gwrs->next();
        is $gwr->workspace_id, $wksp_a->workspace_id,
            '... with Workspace A second';
        is $gwr->workspace->user_count(), '1',
            '.... ... with 1 users';
    }
}

###############################################################################
# TEST: create a new GWR, retrieve from DB
create_gwr: {
    my $user      = create_test_user();
    my $group     = create_test_group();
    my $workspace = create_test_workspace(user => $user);
    my $role      = Socialtext::Role->new(name => 'guest');

    # create the GWR, make sure it got created with our info
#     clear_events();
    clear_log();
    my $gwr   = Socialtext::GroupWorkspaceRoleFactory->Create( {
        group_id     => $group->group_id,
        workspace_id => $workspace->workspace_id,
        role_id      => $role->role_id,
    } );
    isa_ok $gwr, 'Socialtext::GroupWorkspaceRole', 'created GWR';
    is $gwr->group_id, $group->group_id, '... with provided group_id';
    is $gwr->workspace_id, $workspace->workspace_id,
        '... with provided workspace_id';
    is $gwr->role_id, $role->role_id, '... with provided role_id';

    # and that an Event was recorded
#     event_ok(
#         event_class => 'workspace',
#         action      => 'create_role',
#     );

    # and that an entry was logged
    logged_like 'info', qr/ASSIGN,GROUP_WORKSPACE_ROLE/,
        '... creation was logged';

    # double-check that we can pull this GWR from the DB
    my $queried = Socialtext::GroupWorkspaceRoleFactory->Get(
        group_id     => $group->group_id,
        workspace_id => $workspace->workspace_id,
    );
    isa_ok $queried, 'Socialtext::GroupWorkspaceRole', 'queried GWR';
    is $queried->group_id, $group->group_id, '... with expected group_id';
    is $queried->workspace_id, $workspace->workspace_id,
        '... with expected workspace_id';
    is $queried->role_id, $role->role_id, '... with expected role_id';
}

###############################################################################
# TEST: create an GWR with a default Role
create_gwr_with_default_role: {
    my $user  = create_test_user();
    my $ws    = create_test_workspace(user => $user);
    my $group = create_test_group();

    my $gwr   = Socialtext::GroupWorkspaceRoleFactory->Create( {
        group_id     => $group->group_id,
        workspace_id => $ws->workspace_id,
    } );
    isa_ok $gwr, 'Socialtext::GroupWorkspaceRole', 'created GWR';
    is $gwr->role_id, Socialtext::GroupWorkspaceRoleFactory->DefaultRoleId(),
        '... with default role_id';
}

###############################################################################
# TEST: create GWR with additional attributes
create_gwr_with_additional_attributes: {
    my $user  = create_test_user();
    my $ws    = create_test_workspace(user => $user);
    my $group = create_test_group();

    # GWR gets created, and we don't die a horrible death due to unknown extra
    # additional attributes
    my $gwr;
    lives_ok sub {
        $gwr   = Socialtext::GroupWorkspaceRoleFactory->Create( {
            group_id     => $group->group_id,
            workspace_id => $ws->workspace_id,
            bogus        => 'attribute',
        } );
    }, 'created GWR when additional attributes provided';
    isa_ok $gwr, 'Socialtext::GroupWorkspaceRole', '... created GWR';
}

###############################################################################
# TEST: create a duplicate GWR
create_duplicate_gwr: {
    my $user  = create_test_user();
    my $ws    = create_test_workspace(user => $user);
    my $group = create_test_group();

    # create the GWR
    my $gwr   = Socialtext::GroupWorkspaceRoleFactory->Create( {
        group_id     => $group->group_id,
        workspace_id => $ws->workspace_id,
        } );
    isa_ok $gwr, 'Socialtext::GroupWorkspaceRole', 'created GWR';

    # create a duplicate GWR
    dies_ok {
        my $dupe = Socialtext::GroupWorkspaceRoleFactory->Create( {
            group_id     => $group->group_id,
            workspace_id => $ws->workspace_id,
        } );
    } 'creating a duplicate record dies.';
}

###############################################################################
# TEST: update a GWR
update_a_gwr: {
    my $user        = create_test_user();
    my $ws          = create_test_workspace(user => $user);
    my $group       = create_test_group();
    my $member_role = Socialtext::Role->new(name => 'member');
    my $guest_role  = Socialtext::Role->new(name => 'guest');
    my $factory     = Socialtext::GroupWorkspaceRoleFactory->instance();

    # create the GWR
    my $gwr   = $factory->Create( {
        group_id     => $group->group_id,
        workspace_id => $ws->workspace_id,
        role_id      => $member_role->role_id,
        } );
    isa_ok $gwr, 'Socialtext::GroupWorkspaceRole', 'created GWR';

    # update the GWR
#     clear_events();
    clear_log();

    my $rc = $factory->Update($gwr, { role_id => $guest_role->role_id } );
    ok $rc, 'updated GWR';
    is $gwr->role_id, $guest_role->role_id, '... with updated role_id';

    # and that an Event was recorded
#     event_ok(
#         event_class => 'workspace',
#         action      => 'update_role',
#     );

    # and that an entry was logged
    logged_like 'info', qr/CHANGE,GROUP_WORKSPACE_ROLE/,
        '... update was logged';

    # make sure the updates are reflected in the DB
    my $queried = $factory->Get(
        group_id     => $group->group_id,
        workspace_id => $ws->workspace_id,
    );
    is $queried->role_id, $guest_role->role_id, '... which is reflected in DB';
}

###############################################################################
# TEST: ignores updates to "group_id" primary key
ignore_update_to_group_id_pkey: {
    my $user      = create_test_user();
    my $ws        = create_test_workspace(user => $user);
    my $group_one = create_test_group();
    my $group_two = create_test_group();
    my $factory   = Socialtext::GroupWorkspaceRoleFactory->instance();

    # create the GWR
    my $gwr   = $factory->Create( {
        group_id     => $group_one->group_id,
        workspace_id => $ws->workspace_id,
        } );
    isa_ok $gwr, 'Socialtext::GroupWorkspaceRole', 'created GWR';

    # update the GWR
#     clear_events();
    clear_log();
    my $rc = $factory->Update($gwr, { group_id => $group_two->group_id } );
    ok $rc, 'updated GWR';
    is $gwr->group_id, $group_one->group_id, '... GWR has original group_id';

    # and that *NO* Event was recorded
#     is_event_count(0);

    # and that *NO* entry was logged
    logged_not_like 'info', qr/GROUP_WORKSPACE_ROLE/,
        '... NO update was logged';
}

###############################################################################
# TEST: ignores updates to "workspace_id" primary key
ignore_update_to_workspace_id_pkey: {
    my $user    = create_test_user();
    my $ws_one  = create_test_workspace(user => $user);
    my $ws_two  = create_test_workspace(user => $user);
    my $group   = create_test_group();
    my $factory = Socialtext::GroupWorkspaceRoleFactory->instance();

    # create the GWR
    my $gwr   = $factory->Create( {
        group_id     => $group->group_id,
        workspace_id => $ws_one->workspace_id,
        } );
    isa_ok $gwr, 'Socialtext::GroupWorkspaceRole', 'created GWR';

    # update the GWR
#     clear_events();
    clear_log();
    my $rc = $factory->Update($gwr, { workspace_id => $ws_two->workspace_id } );
    ok $rc, 'updated GWR';
    is $gwr->workspace_id, $ws_one->workspace_id,
        '... GWR has original workspace_id';

    # and that *NO* Event was recorded
#     is_event_count(0);

    # and that *NO* entry was logged
    logged_not_like 'info', qr/GROUP_WORKSPACE_ROLE/,
        '... NO update was logged';
}

###############################################################################
# TEST: update a non-existing GWR
update_non_existing_gwr: {
    my $gwr = Socialtext::GroupWorkspaceRole->new( {
        group_id     => 987654321,
        workspace_id => 987654321,
        role_id      => 987654321,
        } );
    isa_ok $gwr, 'Socialtext::GroupWorkspaceRole';

    # Updating a non-existing GWR fails silently; it *looks like* it was ok,
    # but nothing actually got updated in the DB.
    #
    # This mimics the behaviour of ST::User for ST::UserWorkspaceRole.
#     clear_events();
    clear_log();
    lives_ok {
        Socialtext::GroupWorkspaceRoleFactory->Update(
            $gwr,
            { role_id => Socialtext::GroupWorkspaceRoleFactory->DefaultRoleId() },
        );
    } 'updating an non-existing GWR lives (but updates nothing)';

    # and that *NO* Event was recorded
#     is_event_count(0);

    # and that *NO* entry was logged
    logged_not_like 'info', qr/GROUP_WORKSPACE_ROLE/,
        '... NO update was logged';
}

###############################################################################
# TEST: delete an GWR
delete_gwr: {
    my $user      = create_test_user();
    my $workspace = create_test_workspace(user => $user);
    my $group     = create_test_group();
    my $factory   = Socialtext::GroupWorkspaceRoleFactory->instance();

    # create the GWR
    my $gwr   = $factory->Create( {
        group_id     => $group->group_id,
        workspace_id => $workspace->workspace_id,
        } );
    isa_ok $gwr, 'Socialtext::GroupWorkspaceRole', 'created GWR';

    # delete the GWR
#     clear_events();
    clear_log();
    my $rc = $factory->Delete($gwr);
    ok $rc, 'deleted the GWR';

    # and that an Event was recorded
#     event_ok(
#         event_class => 'workspace',
#         action      => 'delete_role',
#     );

    # and that an entry was logged
    logged_like 'info', qr/REMOVE,GROUP_WORKSPACE_ROLE/,
        '... removal was logged';

    # make sure the delete was reflected in the DB
    my $queried = $factory->Get(
        group_id     => $group->group_id,
        workspace_id => $workspace->workspace_id,
    );
    ok !$queried, '... which is reflected in DB';
}

###############################################################################
# TEST: delete a non-existing GWR
delete_non_existing_gwr: {
    my $gwr = Socialtext::GroupWorkspaceRole->new( {
        group_id     => 987654321,
        workspace_id => 987654321,
        role_id      => 987654321,
        } );
    isa_ok $gwr, 'Socialtext::GroupWorkspaceRole';

    # Deleting a non-existing GWR fails, without throwing an exception
#     clear_events();
    clear_log();
    my $factory = Socialtext::GroupWorkspaceRoleFactory->instance();
    my $rc      = $factory->Delete($gwr);
    ok !$rc, 'cannot delete a non-existing GWR';

    # and that *NO* Event was recorded
#     is_event_count(0);

    # and that *NO* entry was logged
    logged_not_like 'info', qr/GROUP_WORKSPACE_ROLE/,
        '... NO removal was logged';
}

################################################################################
# TEST: ByGroupId 
by_group_id: {
    my $user   = create_test_user();
    my $ws_one = create_test_workspace(user => $user);
    my $ws_two = create_test_workspace(user => $user);
    my $group  = create_test_group();

    # Create GWRs
    Socialtext::GroupWorkspaceRoleFactory->Create( {
        group_id     => $group->group_id,
        workspace_id => $ws_one->workspace_id,
    } );

    Socialtext::GroupWorkspaceRoleFactory->Create( {
        group_id     => $group->group_id,
        workspace_id => $ws_two->workspace_id,
    } );

    my $workspaces = Socialtext::GroupWorkspaceRoleFactory->ByGroupId(
        $group->group_id
    );
    isa_ok $workspaces, 'Socialtext::MultiCursor', 'Got a list of results';
    is $workspaces->count(), 2, '... of correct size';

    my $q_ws_one = $workspaces->next();
    isa_ok $q_ws_one, 'Socialtext::GroupWorkspaceRole', 'First result';
    is $q_ws_one->workspace_id, $ws_one->workspace_id,
        '... with correct workspace_id';

    my $q_ws_two = $workspaces->next();
    isa_ok $q_ws_two, 'Socialtext::GroupWorkspaceRole', 'Second result';
    is $q_ws_two->workspace_id, $ws_two->workspace_id,
        '... with correct workspace_id';
}

################################################################################
# TEST: ByGroupId -- passing in a closure.
by_group_id_with_closure: {
    my $user   = create_test_user();
    my $ws_one = create_test_workspace(user => $user);
    my $ws_two = create_test_workspace(user => $user);
    my $group  = create_test_group();

    # Create GWRs
    Socialtext::GroupWorkspaceRoleFactory->Create( {
        group_id     => $group->group_id,
        workspace_id => $ws_one->workspace_id,
    } );

    Socialtext::GroupWorkspaceRoleFactory->Create( {
        group_id     => $group->group_id,
        workspace_id => $ws_two->workspace_id,
    } );

    my $workspaces = Socialtext::GroupWorkspaceRoleFactory->ByGroupId( 
        $group->group_id,
        sub { shift->workspace(); }
    );
    isa_ok $workspaces, 'Socialtext::MultiCursor', 'Got a list of results';
    is $workspaces->count(), 2, '... of correct size';

    my $q_ws_one = $workspaces->next();
    isa_ok $q_ws_one, 'Socialtext::Workspace', 'First result';
    is $q_ws_one->name, $ws_one->name, '... with correct name';

    my $q_ws_two = $workspaces->next();
    isa_ok $q_ws_two, 'Socialtext::Workspace', 'Second result';
    is $q_ws_two->name, $ws_two->name, '... with correct name';
}

################################################################################
# TEST: ByGroupId with non-existing group_id
by_group_id_with_non_existing_group_id: {
    my $gwrs = Socialtext::GroupWorkspaceRoleFactory->ByGroupId( 12345678 );

    isa_ok $gwrs, 'Socialtext::MultiCursor', 'Got a list';
    ok !$gwrs->count(), '... with no results';
}

###############################################################################
# TEST: ByWorkspaceId 
by_workspace_id: {
    my $user      = create_test_user();
    my $ws        = create_test_workspace(user => $user);
    my $group_one = create_test_group();
    my $group_two = create_test_group();

    # Create GWRs
    Socialtext::GroupWorkspaceRoleFactory->Create( {
        group_id     => $group_one->group_id,
        workspace_id => $ws->workspace_id,
    } );

    Socialtext::GroupWorkspaceRoleFactory->Create( {
        group_id     => $group_two->group_id,
        workspace_id => $ws->workspace_id,
    } );

    my $groups = Socialtext::GroupWorkspaceRoleFactory->ByWorkspaceId(
        $ws->workspace_id
    );
    isa_ok $groups, 'Socialtext::MultiCursor', 'Got a list';
    is $groups->count, 2, '... of correct size';

    my $q_group_one = $groups->next();
    isa_ok $q_group_one, 'Socialtext::GroupWorkspaceRole', 'Got first group';
    is $q_group_one->group_id, $group_one->group_id, '... with right group_id';

    my $q_group_two = $groups->next();
    isa_ok $q_group_two, 'Socialtext::GroupWorkspaceRole', 'Got second group';
    is $q_group_two->group_id, $group_two->group_id, '... with right group_id';
}

################################################################################
# TEST: ByWorkspaceId -- passing in a closure.
by_workspace_id_with_closure: {
    my $user      = create_test_user();
    my $ws        = create_test_workspace(user => $user);
    my $group_one = create_test_group();
    my $group_two = create_test_group();

    # Create GWRs
    Socialtext::GroupWorkspaceRoleFactory->Create( {
        group_id     => $group_one->group_id,
        workspace_id => $ws->workspace_id,
    } );

    Socialtext::GroupWorkspaceRoleFactory->Create( {
        group_id     => $group_two->group_id,
        workspace_id => $ws->workspace_id,
    } );

    my $groups = Socialtext::GroupWorkspaceRoleFactory->ByWorkspaceId( 
        $ws->workspace_id,
        sub { shift->group(); },
    );

    isa_ok $groups, 'Socialtext::MultiCursor', 'Got a list';
    is $groups->count, 2, '... of correct size';
    
    my $q_group_one = $groups->next();
    isa_ok $q_group_one, 'Socialtext::Group', 'Got first group';
    is $q_group_one->driver_group_name, $group_one->driver_group_name, 
        '... with right name';

    my $q_group_two = $groups->next();
    isa_ok $q_group_two, 'Socialtext::Group', 'Got second group';
    is $q_group_two->driver_group_name, $group_two->driver_group_name, 
        '... with right name';
}

################################################################################
# TEST: ByWorkspaceId with non-existing workspace_id
by_workspace_id_with_non_existing_workspace_id: {
    my $groups = Socialtext::GroupWorkspaceRoleFactory->ByWorkspaceId(
        123456789
    );

    isa_ok $groups, 'Socialtext::MultiCursor', 'Got a list';
    ok !$groups->count(), '... with no results';
}
