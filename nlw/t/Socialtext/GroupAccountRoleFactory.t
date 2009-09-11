#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
# use mocked 'Socialtext::Events', qw(clear_events event_ok is_event_count);
use mocked 'Socialtext::Log', qw(:tests);
use Test::Socialtext tests => 94;
use Test::Exception;

###############################################################################
# Fixtures: db
# - need a DB, don't care what's in it
fixtures(qw( db ));

use_ok 'Socialtext::GroupAccountRoleFactory';

###############################################################################
# TEST: get a Factory instance
get_factory_instance: {
    # "new()" gets us a Factory
    my $instance_one = Socialtext::GroupAccountRoleFactory->new();
    isa_ok $instance_one, 'Socialtext::GroupAccountRoleFactory';

    # "instance()" gets us a Factory
    my $instance_two = Socialtext::GroupAccountRoleFactory->instance();
    isa_ok $instance_two, 'Socialtext::GroupAccountRoleFactory';

    # its the *same* Factory
    is $instance_one, $instance_two, '... and its the same Factory';
}

###############################################################################
# TEST: create a new GAR, retrieve from DB
create_gar: {
    my $user    = create_test_user();
    my $group   = create_test_group();
    my $account = create_test_account_bypassing_factory();
    my $role    = Socialtext::Role->new(name => 'guest');

    # create the GAR, make sure it got created with our info
#     clear_events();
    clear_log();
    my $gar = Socialtext::GroupAccountRoleFactory->Create( {
        group_id   => $group->group_id,
        account_id => $account->account_id,
        role_id    => $role->role_id,
    } );
    isa_ok $gar, 'Socialtext::GroupAccountRole', 'created GAR';
    is $gar->group_id, $group->group_id, '... with provided group_id';
    is $gar->account_id, $account->account_id,
        '... with provided account_id';
    is $gar->role_id, $role->role_id, '... with provided role_id';

    # and that an Event was recorded
#     event_ok(
#         event_class => 'account',
#         action      => 'create_role',
#     );

    # and that an entry was logged
    logged_like 'info', qr/ASSIGN,GROUP_ACCOUNT_ROLE/,
        '... creation was logged';

    # double-check that we can pull this GAR from the DB
    my $queried = Socialtext::GroupAccountRoleFactory->Get(
        group_id     => $group->group_id,
        account_id => $account->account_id,
    );
    isa_ok $queried, 'Socialtext::GroupAccountRole', 'queried GAR';
    is $queried->group_id, $group->group_id, '... with expected group_id';
    is $queried->account_id, $account->account_id,
        '... with expected account_id';
    is $queried->role_id, $role->role_id, '... with expected role_id';
}

###############################################################################
# TEST: create an GAR with a default Role
create_gar_with_default_role: {
    my $user    = create_test_user();
    my $account = create_test_account_bypassing_factory();
    my $group   = create_test_group();

    my $gar = Socialtext::GroupAccountRoleFactory->Create( {
        group_id   => $group->group_id,
        account_id => $account->account_id,
    } );
    isa_ok $gar, 'Socialtext::GroupAccountRole', 'created GAR';
    is $gar->role_id, Socialtext::GroupAccountRoleFactory->DefaultRoleId(),
        '... with default role_id';
}

###############################################################################
# TEST: create GAR with additional attributes
create_gar_with_additional_attributes: {
    my $user    = create_test_user();
    my $account = create_test_account_bypassing_factory();
    my $group   = create_test_group();

    # GAR gets created, and we don't die a horrible death due to unknown extra
    # additional attributes
    my $gar;
    lives_ok sub {
        $gar   = Socialtext::GroupAccountRoleFactory->Create( {
            group_id   => $group->group_id,
            account_id => $account->account_id,
            bogus      => 'attribute',
        } );
    }, 'created GAR when additional attributes provided';
    isa_ok $gar, 'Socialtext::GroupAccountRole', '... created GAR';
}

###############################################################################
# TEST: create a duplicate GAR
create_duplicate_gar: {
    my $user    = create_test_user();
    my $account = create_test_account_bypassing_factory();
    my $group   = create_test_group();

    # create the GAR
    my $gar = Socialtext::GroupAccountRoleFactory->Create( {
        group_id   => $group->group_id,
        account_id => $account->account_id,
        } );
    isa_ok $gar, 'Socialtext::GroupAccountRole', 'created GAR';

    # create a duplicate GAR
    dies_ok {
        my $dupe = Socialtext::GroupAccountRoleFactory->Create( {
            group_id   => $group->group_id,
            account_id => $account->account_id,
        } );
    } 'creating a duplicate record dies.';
}

###############################################################################
# TEST: update a GAR
update_a_gar: {
    my $user        = create_test_user();
    my $account     = create_test_account_bypassing_factory();
    my $group       = create_test_group();
    my $member_role = Socialtext::Role->new(name => 'member');
    my $guest_role  = Socialtext::Role->new(name => 'guest');
    my $factory     = Socialtext::GroupAccountRoleFactory->instance();

    # create the GAR
    my $gar = $factory->Create( {
        group_id   => $group->group_id,
        account_id => $account->account_id,
        role_id    => $member_role->role_id,
        } );
    isa_ok $gar, 'Socialtext::GroupAccountRole', 'created GAR';

    # update the GAR
#     clear_events();
    clear_log();
    my $rc = $factory->Update($gar, { role_id => $guest_role->role_id } );
    ok $rc, 'updated GAR';
    is $gar->role_id, $guest_role->role_id, '... with updated role_id';

    # and that an Event was recorded
#     event_ok(
#         event_class => 'account',
#         action      => 'update_role',
#     );

    # and that an entry was logged
    logged_like 'info', qr/CHANGE,GROUP_ACCOUNT_ROLE/,
        '... update was logged';

    # make sure the updates are reflected in the DB
    my $queried = $factory->Get(
        group_id   => $group->group_id,
        account_id => $account->account_id,
    );
    is $queried->role_id, $guest_role->role_id, '... which is reflected in DB';
}

###############################################################################
# TEST: ignores updates to "group_id" primary key
ignore_update_to_group_id_pkey: {
    my $user      = create_test_user();
    my $account   = create_test_account_bypassing_factory();
    my $group_one = create_test_group();
    my $group_two = create_test_group();
    my $factory   = Socialtext::GroupAccountRoleFactory->instance();

    # create the GAR
    my $gar = $factory->Create( {
        group_id   => $group_one->group_id,
        account_id => $account->account_id,
        } );
    isa_ok $gar, 'Socialtext::GroupAccountRole', 'created GAR';

    # update the GAR
#     clear_events();
    clear_log();
    my $rc = $factory->Update($gar, { group_id => $group_two->group_id } );
    ok $rc, 'updated GAR';
    is $gar->group_id, $group_one->group_id, '... GAR has original group_id';

    # and that *NO* Event was recorded
#     is_event_count(0);

    # and that *NO* entry was logged
    logged_not_like 'info', qr/GROUP_ACCOUNT_ROLE/,
        '... NO update was logged';
}

###############################################################################
# TEST: ignores updates to "account_id" primary key
ignore_update_to_account_id_pkey: {
    my $user     = create_test_user();
    my $acct_one = create_test_account_bypassing_factory();
    my $acct_two = create_test_account_bypassing_factory();
    my $group    = create_test_group();
    my $factory  = Socialtext::GroupAccountRoleFactory->instance();

    # create the GAR
    my $gar = $factory->Create( {
        group_id   => $group->group_id,
        account_id => $acct_one->account_id,
        } );
    isa_ok $gar, 'Socialtext::GroupAccountRole', 'created GAR';

    # update the GAR
#     clear_events();
    clear_log();
    my $rc = $factory->Update($gar, { account_id => $acct_two->account_id } );
    ok $rc, 'updated GAR';
    is $gar->account_id, $acct_one->account_id,
        '... GAR has original account_id';

    # and that *NO* Event was recorded
#     is_event_count(0);

    # and that *NO* entry was logged
    logged_not_like 'info', qr/GROUP_ACCOUNT_ROLE/,
        '... NO update was logged';
}

###############################################################################
# TEST: update a non-existing GAR
update_non_existing_gar: {
    my $gar = Socialtext::GroupAccountRole->new( {
        group_id    => 987654321,
        account_id  => 987654321,
        role_id     => 987654321,
        } );
    isa_ok $gar, 'Socialtext::GroupAccountRole';

    # Updating a non-existing GAR fails silently; it *looks like* it was ok,
    # but nothing actually got updated in the DB.
    #
    # This mimics the behaviour of ST::User for ST::UserAccountRole.
#     clear_events();
    clear_log();
    lives_ok {
        Socialtext::GroupAccountRoleFactory->Update(
            $gar,
            { role_id => Socialtext::GroupAccountRoleFactory->DefaultRoleId() },
        );
    } 'updating an non-existing GAR lives (but updates nothing)';

    # and that *NO* Event was recorded
#     is_event_count(0);

    # and that *NO* entry was logged
    logged_not_like 'info', qr/GROUP_ACCOUNT_ROLE/,
        '... NO update was logged';
}

###############################################################################
# TEST: delete an GAR
delete_gar: {
    my $user    = create_test_user();
    my $account = create_test_account_bypassing_factory();
    my $group   = create_test_group();
    my $factory = Socialtext::GroupAccountRoleFactory->instance();

    # create the GAR
    my $gar = $factory->Create( {
        group_id   => $group->group_id,
        account_id => $account->account_id,
        } );
    isa_ok $gar, 'Socialtext::GroupAccountRole', 'created GAR';

    # delete the GAR
#     clear_events();
    clear_log();
    my $rc = $factory->Delete($gar);
    ok $rc, 'deleted the GAR';

    # and that an Event was recorded
#     event_ok(
#         event_class => 'account',
#         action      => 'delete_role',
#     );

    # and that an entry was logged
    logged_like 'info', qr/REMOVE,GROUP_ACCOUNT_ROLE/,
        '... removal was logged';

    # make sure the delete was reflected in the DB
    my $queried = $factory->Get(
        group_id   => $group->group_id,
        account_id => $account->account_id,
    );
    ok !$queried, '... which is reflected in DB';
}

###############################################################################
# TEST: delete a non-existing GAR
delete_non_existing_gar: {
    my $gar = Socialtext::GroupAccountRole->new( {
        group_id   => 987654321,
        account_id => 987654321,
        role_id    => 987654321,
        } );
    isa_ok $gar, 'Socialtext::GroupAccountRole';

    # Deleting a non-existing GAR fails, without throwing an exception
#     clear_events();
    clear_log();
    my $factory = Socialtext::GroupAccountRoleFactory->instance();
    my $rc      = $factory->Delete($gar);
    ok !$rc, 'cannot delete a non-existing GAR';

    # and that *NO* Event was recorded
#     is_event_count(0);

    # and that *NO* entry was logged
    logged_not_like 'info', qr/GROUP_ACCOUNT_ROLE/,
        '... NO removal was logged';
}

################################################################################
# TEST: ByGroupId 
by_group_id: {
    my $acct_one = create_test_account_bypassing_factory();
    my $acct_two = create_test_account_bypassing_factory();
    my $group    = create_test_group(account => $acct_one);

    # Create a second, explicit GAR
    Socialtext::GroupAccountRoleFactory->Create( {
        group_id   => $group->group_id,
        account_id => $acct_two->account_id,
    } );

    my $accounts = Socialtext::GroupAccountRoleFactory->ByGroupId(
        $group->group_id
    );
    isa_ok $accounts, 'Socialtext::MultiCursor', 'Got a list of results';
    is $accounts->count(), 2, '... of correct size';

    my $q_acct_one = $accounts->next();
    isa_ok $q_acct_one, 'Socialtext::GroupAccountRole', 'First result';
    is $q_acct_one->account_id, $acct_one->account_id,
        '... with correct account_id';

    my $q_acct_two = $accounts->next();
    isa_ok $q_acct_two, 'Socialtext::GroupAccountRole', 'Second result';
    is $q_acct_two->account_id, $acct_two->account_id,
        '... with correct account_id';
}

################################################################################
# TEST: ByGroupId -- passing in a closure.
by_group_id_with_closure: {
    my $acct_one = create_test_account_bypassing_factory();
    my $acct_two = create_test_account_bypassing_factory();
    my $group    = create_test_group(account => $acct_one);

    # Create a second, explicit GAR
    Socialtext::GroupAccountRoleFactory->Create( {
        group_id   => $group->group_id,
        account_id => $acct_two->account_id,
    } );

    my $accounts = Socialtext::GroupAccountRoleFactory->ByGroupId( 
        $group->group_id,
        sub { shift->account(); }
    );
    isa_ok $accounts, 'Socialtext::MultiCursor', 'Got a list of results';
    is $accounts->count(), 2, '... of correct size';

    my $q_acct_one = $accounts->next();
    isa_ok $q_acct_one, 'Socialtext::Account', 'First result';
    is $q_acct_one->name, $acct_one->name, '... with correct name';

    my $q_acct_two = $accounts->next();
    isa_ok $q_acct_two, 'Socialtext::Account', 'Second result';
    is $q_acct_two->name, $acct_two->name, '... with correct name';
}

################################################################################
# TEST: ByGroupId with non-existing group_id
by_group_id_with_non_existing_group_id: {
    my $gars = Socialtext::GroupAccountRoleFactory->ByGroupId( 12345678 );

    isa_ok $gars, 'Socialtext::MultiCursor', 'Got a list';
    ok !$gars->count(), '... with no results';
}

###############################################################################
# TEST: ByAccountId 
by_account_id: {
    my $user      = create_test_user();
    my $account   = create_test_account_bypassing_factory();
    my $group_one = create_test_group();
    my $group_two = create_test_group();

    # Create GARs
    Socialtext::GroupAccountRoleFactory->Create( {
        group_id   => $group_one->group_id,
        account_id => $account->account_id,
    } );

    Socialtext::GroupAccountRoleFactory->Create( {
        group_id   => $group_two->group_id,
        account_id => $account->account_id,
    } );

    my $groups = Socialtext::GroupAccountRoleFactory->ByAccountId(
        $account->account_id
    );
    isa_ok $groups, 'Socialtext::MultiCursor', 'Got a list';
    is $groups->count, 2, '... of correct size';

    my $q_group_one = $groups->next();
    isa_ok $q_group_one, 'Socialtext::GroupAccountRole', 'Got first group';
    is $q_group_one->group_id, $group_one->group_id, '... with right group_id';

    my $q_group_two = $groups->next();
    isa_ok $q_group_two, 'Socialtext::GroupAccountRole', 'Got second group';
    is $q_group_two->group_id, $group_two->group_id, '... with right group_id';
}

################################################################################
# TEST: ByAccountId -- passing in a closure.
by_account_id_with_closure: {
    my $user      = create_test_user();
    my $account   = create_test_account_bypassing_factory();
    my $group_one = create_test_group();
    my $group_two = create_test_group();

    # Create GARs
    Socialtext::GroupAccountRoleFactory->Create( {
        group_id   => $group_one->group_id,
        account_id => $account->account_id,
    } );

    Socialtext::GroupAccountRoleFactory->Create( {
        group_id   => $group_two->group_id,
        account_id => $account->account_id,
    } );

    my $groups = Socialtext::GroupAccountRoleFactory->ByAccountId( 
        $account->account_id,
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
# TEST: ByAccountId with non-existing account_id
by_account_id_with_non_existing_account_id: {
    my $groups = Socialtext::GroupAccountRoleFactory->ByAccountId(
        123456789
    );

    isa_ok $groups, 'Socialtext::MultiCursor', 'Got a list';
    ok !$groups->count(), '... with no results';
}

################################################################################
sorted_by_name: {
    my $acct1 = create_test_account_bypassing_factory('Development');
    my $acct2 = create_test_account_bypassing_factory('Sales');
    my $acct3 = create_test_account_bypassing_factory('Default');
    my $group = create_test_group(account => $acct3);

    $acct1->add_group( group => $group );
    $acct2->add_group( group => $group );

    diag 'Sorted by name';

    # Default sort order
    my $accounts = Socialtext::GroupAccountRoleFactory->SortedResultSet(
        group_id => $group->group_id,
        order_by => 'name',
    );

    is $accounts->count => 3, 'Default order returns 2 accounts...';
    is_deeply [ $acct3->account_id, $acct1->account_id, $acct2->account_id ],
        [ map { $_->{account_id} } $accounts->all() ], '... in correct order';

    # Ascending sort order
    $accounts = Socialtext::GroupAccountRoleFactory->SortedResultSet(
        group_id   => $group->group_id,
        order_by   => 'name',
        sort_order => 'asc',
    );

    is $accounts->count => 3, 'Ascending order returns 2 accounts...';
    is_deeply [ $acct3->account_id, $acct1->account_id, $acct2->account_id ],
        [ map { $_->{account_id} } $accounts->all() ], '... in correct order';

    # Descending sort order
    $accounts = Socialtext::GroupAccountRoleFactory->SortedResultSet(
        group_id   => $group->group_id,
        order_by   => 'name',
        sort_order => 'desc',
    );

    is $accounts->count => 3, 'Descending order returns 2 accounts...';
    is_deeply [ $acct2->account_id, $acct1->account_id, $acct3->account_id ],
        [ map { $_->{account_id} } $accounts->all() ], '... in correct order';
}

################################################################################
sorted_by_user_count: {
    my $acct1 = create_test_account_bypassing_factory();
    my $acct2 = create_test_account_bypassing_factory();
    my $acct3 = create_test_account_bypassing_factory();
    my $user1 = create_test_user( account => $acct1 );
    my $user2 = create_test_user( account => $acct1 );
    my $user3 = create_test_user( account => $acct2 );
    my $group = create_test_group(account => $acct3);

    $acct1->add_group( group => $group );
    $acct2->add_group( group => $group );

    is $acct1->user_count => 2, 'Account one has 2 users';
    is $acct2->user_count => 1, 'Account two has 1 user';
    is $acct3->user_count => 0, 'Account three has 0 users';

    diag 'Sorted by user_count';

    # Default sort order
    my $accounts = Socialtext::GroupAccountRoleFactory->SortedResultSet(
        group_id => $group->group_id,
        order_by => 'user_count',
    );

    is $accounts->count => 3, 'Default order returns 3 accounts...';
    is_deeply [ $acct2->account_id, $acct1->account_id, $acct3->account_id ],
        [ map { $_->{account_id} } $accounts->all() ], '... in correct order';

    # Ascending sort order
    $accounts = Socialtext::GroupAccountRoleFactory->SortedResultSet(
        group_id   => $group->group_id,
        order_by   => 'user_count',
        sort_order => 'asc',
    );

    is $accounts->count => 3, 'Ascending order returns 3 accounts...';
    is_deeply [ $acct2->account_id, $acct1->account_id, $acct3->account_id ],
        [ map { $_->{account_id} } $accounts->all() ], '... in correct order';

    # Descending sort order
    $accounts = Socialtext::GroupAccountRoleFactory->SortedResultSet(
        group_id   => $group->group_id,
        order_by   => 'user_count',
        sort_order => 'desc',
    );

    is $accounts->count => 3, 'Descending order returns 3 accounts...';
    is_deeply [ $acct3->account_id, $acct1->account_id, $acct2->account_id ],
        [ map { $_->{account_id} } $accounts->all() ], '... in correct order';
}

################################################################################
sorted_by_workspace_count: {
    my $acct1 = create_test_account_bypassing_factory();
    my $acct2 = create_test_account_bypassing_factory();
    my $acct3 = create_test_account_bypassing_factory();
    my $ws1   = create_test_workspace(account => $acct1);
    my $ws2   = create_test_workspace(account => $acct1);
    my $ws3   = create_test_workspace(account => $acct2);
    my $group = create_test_group(account => $acct3);

    $acct1->add_group( group => $group );
    $acct2->add_group( group => $group );

    is $acct1->workspace_count => 2, 'Account one has 2 workspaces';
    is $acct2->workspace_count => 1, 'Account two has 1 workspace';
    is $acct3->workspace_count => 0, 'Account three has 0 workspaces';

    diag 'Sorted by workspace_count';

    # Default sort order
    my $accounts = Socialtext::GroupAccountRoleFactory->SortedResultSet(
        group_id => $group->group_id,
        order_by => 'workspace_count',
    );

    is $accounts->count => 3, 'Default order returns 3 accounts...';
    is_deeply [ $acct2->account_id, $acct1->account_id, $acct3->account_id ],
        [ map { $_->{account_id} } $accounts->all() ], '... in correct order';

    # Ascending sort order
    $accounts = Socialtext::GroupAccountRoleFactory->SortedResultSet(
        group_id   => $group->group_id,
        order_by   => 'workspace_count',
        sort_order => 'asc',
    );

    is $accounts->count => 3, 'Ascending order returns 3 accounts...';
    is_deeply [ $acct2->account_id, $acct1->account_id, $acct3->account_id ],
        [ map { $_->{account_id} } $accounts->all() ], '... in correct order';

    # Descending sort order
    $accounts = Socialtext::GroupAccountRoleFactory->SortedResultSet(
        group_id   => $group->group_id,
        order_by   => 'workspace_count',
        sort_order => 'desc',
    );

    is $accounts->count => 3, 'Descending order returns 3 accounts...';
    is_deeply [ $acct3->account_id, $acct1->account_id, $acct2->account_id ],
        [ map { $_->{account_id} } $accounts->all() ], '... in correct order';
}
