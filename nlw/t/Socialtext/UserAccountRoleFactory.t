#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use mocked 'Socialtext::Events', qw(clear_events event_ok is_event_count);
use mocked 'Socialtext::Log', qw(:tests);
use Test::Socialtext tests => 84;
use Test::Exception;

###############################################################################
# Fixtures: db
# - need a DB, don't care what's in it
fixtures(qw( db ));

use_ok 'Socialtext::UserAccountRoleFactory';

###############################################################################
# TEST: get a Factory instance
get_factory_instance: {
    # "new()" gets us a Factory
    my $instance_one = Socialtext::UserAccountRoleFactory->new();
    isa_ok $instance_one, 'Socialtext::UserAccountRoleFactory';

    # "instance()" gets us a Factory
    my $instance_two = Socialtext::UserAccountRoleFactory->instance();
    isa_ok $instance_two, 'Socialtext::UserAccountRoleFactory';

    # its the *same* Factory
    is $instance_one, $instance_two, '... and its the same Factory';
}

###############################################################################
# TEST: create a new UAR, retrieve from DB
create_uar: {
    my $user    = create_test_user();
    my $account = create_test_account_bypassing_factory();
    my $role    = Socialtext::Role->new(name => 'guest');

    # create the UAR, make sure it got created with our info
    clear_events();
    clear_log();
    my $uar   = Socialtext::UserAccountRoleFactory->Create( {
        user_id    => $user->user_id,
        account_id => $account->account_id,
        role_id    => $role->role_id,
    } );
    isa_ok $uar, 'Socialtext::UserAccountRole', 'created UAR';
    is $uar->user_id,  $user->user_id,         '... with provided user_id';
    is $uar->account_id, $account->account_id, '... with provided account_id';
    is $uar->role_id,  $role->role_id,         '... with provided role_id';

    # and that an Event was recorded
    event_ok(
        event_class => 'account',
        action      => 'create_role',
    );

    # and that an entry was logged
    logged_like 'info', qr/ASSIGN,ACCOUNT_ROLE/, '... creation was logged';

    # double-check that we can pull this UAR from the DB
    my $queried = Socialtext::UserAccountRoleFactory->Get(
        user_id    => $user->user_id,
        account_id => $account->account_id,
    );
    isa_ok $queried, 'Socialtext::UserAccountRole', 'queried UAR';
    is $queried->user_id,  $user->user_id,         '... with expected user_id';
    is $queried->account_id, $account->account_id, '... with expected account_id';
    is $queried->role_id,  $role->role_id,         '... with expected role_id';
}

###############################################################################
# TEST: create an UAR with a default Role
create_uar_with_default_role: {
    my $user    = create_test_user();
    my $account = create_test_account_bypassing_factory();

    my $uar   = Socialtext::UserAccountRoleFactory->Create( {
        user_id    => $user->user_id,
        account_id => $account->account_id,
    } );
    isa_ok $uar, 'Socialtext::UserAccountRole', 'created UAR';
    is $uar->role_id, Socialtext::UserAccountRoleFactory->DefaultRoleId(),
        '... with default role_id';
}

###############################################################################
# TEST: create UAR with additional attributes
create_uar_with_additional_attributes: {
    my $user    = create_test_user();
    my $account = create_test_account_bypassing_factory();

    # UAR gets created, and we don't die a horrible death due to unknown extra
    # additional attributes
    my $uar;
    lives_ok sub {
        $uar   = Socialtext::UserAccountRoleFactory->Create( {
            user_id    => $user->user_id,
            account_id => $account->account_id,
            bogus      => 'attribute',
        } );
    }, 'created UAR when additional attributes provided';
    isa_ok $uar, 'Socialtext::UserAccountRole', '... created UAR';
}

###############################################################################
# TEST: create a duplicate UAR
create_duplicate_uar: {
    my $user    = create_test_user();
    my $account = create_test_account_bypassing_factory();

    # create the UAR
    my $uar   = Socialtext::UserAccountRoleFactory->Create( {
        user_id    => $user->user_id,
        account_id => $account->account_id,
        } );
    isa_ok $uar, 'Socialtext::UserAccountRole', 'created UAR';

    # create a duplicate UAR
    dies_ok {
        my $dupe = Socialtext::UserAccountRoleFactory->Create( {
            user_id    => $user->user_id,
            account_id => $account->account_id,
        } );
    } 'creating a duplicate record dies.';
}

###############################################################################
# TEST: update a UAR
update_a_uar: {
    my $user        = create_test_user();
    my $account     = create_test_account_bypassing_factory();
    my $member_role = Socialtext::Role->new(name => 'member');
    my $guest_role  = Socialtext::Role->new(name => 'guest');
    my $factory     = Socialtext::UserAccountRoleFactory->instance();

    # create the UAR
    my $uar   = $factory->Create( {
        user_id    => $user->user_id,
        account_id => $account->account_id,
        role_id    => $member_role->role_id,
        } );
    isa_ok $uar, 'Socialtext::UserAccountRole', 'created UAR';

    # update the UAR
    clear_events();
    clear_log();
    my $rc = $factory->Update($uar, { role_id => $guest_role->role_id } );
    ok $rc, 'updated UAR';
    is $uar->role_id, $guest_role->role_id, '... with updated role_id';

    # and that an Event was recorded
    event_ok(
        event_class => 'account',
        action      => 'update_role',
    );

    # and that an entry was logged
    logged_like 'info', qr/CHANGE,ACCOUNT_ROLE/, '... update was logged';

    # make sure the updates are reflected in the DB
    my $queried = $factory->Get(
        user_id    => $user->user_id,
        account_id => $account->account_id,
    );
    is $queried->role_id, $guest_role->role_id, '... which is reflected in DB';
}

###############################################################################
# TEST: ignores updates to "user_id" primary key
ignore_update_to_user_id_pkey: {
    my $user_one = create_test_user();
    my $user_two = create_test_user();
    my $account  = create_test_account_bypassing_factory();
    my $factory  = Socialtext::UserAccountRoleFactory->instance();

    # create the UAR
    my $uar   = $factory->Create( {
        user_id    => $user_one->user_id,
        account_id => $account->account_id,
        } );
    isa_ok $uar, 'Socialtext::UserAccountRole', 'created UAR';

    # update the UAR
    clear_events();
    clear_log();
    my $rc = $factory->Update($uar, { user_id => $user_two->user_id } );
    ok $rc, 'updated UAR';
    is $uar->user_id, $user_one->user_id, '... UAR has original user_id';

    # and that *NO* Event was recorded
    is_event_count(0);

    # and that *NO* entry was logged
    logged_not_like 'info', qr/ACCOUNT_ROLE/, '... NO update was logged';
}

###############################################################################
# TEST: ignores updates to "account_id" primary key
ignore_update_to_account_id_pkey: {
    my $user        = create_test_user();
    my $account_one = create_test_account_bypassing_factory();
    my $account_two = create_test_account_bypassing_factory();
    my $factory     = Socialtext::UserAccountRoleFactory->instance();

    # create the UAR
    my $uar   = $factory->Create( {
        user_id    => $user->user_id,
        account_id => $account_one->account_id,
        } );
    isa_ok $uar, 'Socialtext::UserAccountRole', 'created UAR';

    # update the UAR
    clear_events();
    clear_log();
    my $rc = $factory->Update($uar, { account_id => $account_two->account_id } );
    ok $rc, 'updated UAR';
    is $uar->account_id, $account_one->account_id, '... UAR has original account_id';

    # and that *NO* Event was recorded
    is_event_count(0);

    # and that *NO* entry was logged
    logged_not_like 'info', qr/ACCOUNT_ROLE/, '... NO update was logged';
}

###############################################################################
# TEST: update a non-existing UAR
update_non_existing_uar: {
    my $uar = Socialtext::UserAccountRole->new( {
        user_id    => 987654321,
        account_id => 987654321,
        role_id    => 987654321,
        } );
    isa_ok $uar, 'Socialtext::UserAccountRole';

    # Updating a non-existing UAR fails silently; it *looks like* it was ok,
    # but nothing actually got updated in the DB.
    #
    # This mimics the behaviour of ST::User and for ST::UserWorkspaceRole.
    clear_events();
    clear_log();
    lives_ok {
        Socialtext::UserAccountRoleFactory->Update(
            $uar,
            { role_id => Socialtext::UserAccountRoleFactory->DefaultRoleId() },
        );
    } 'updating an non-existing UAR lives (but updates nothing)';

    # and that *NO* Event was recorded
    is_event_count(0);

    # and that *NO* entry was logged
    logged_not_like 'info', qr/ACCOUNT_ROLE/, '... NO update was logged';
}

###############################################################################
# TEST: delete an UAR
delete_uar: {
    my $user    = create_test_user();
    my $account = create_test_account_bypassing_factory();
    my $factory = Socialtext::UserAccountRoleFactory->instance();

    # create the UAR
    my $uar   = $factory->Create( {
        user_id    => $user->user_id,
        account_id => $account->account_id,
        } );
    isa_ok $uar, 'Socialtext::UserAccountRole', 'created UAR';

    # delete the UAR
    clear_events();
    clear_log();
    my $rc = $factory->Delete($uar);
    ok $rc, 'deleted the UAR';

    # and that an Event was recorded
    event_ok(
        event_class => 'account',
        action      => 'delete_role',
    );

    # and that an entry was logged
    logged_like 'info', qr/REMOVE,ACCOUNT_ROLE/, '... removal was logged';

    # make sure the delete was reflected in the DB
    my $queried = $factory->Get(
        user_id    => $user->user_id,
        account_id => $account->account_id,
    );
    ok !$queried, '... which is reflected in DB';
}

###############################################################################
# TEST: delete a non-existing UAR
delete_non_existing_uar: {
    my $uar = Socialtext::UserAccountRole->new( {
        user_id    => 987654321,
        account_id => 987654321,
        role_id    => 987654321,
        } );
    isa_ok $uar, 'Socialtext::UserAccountRole';

    # Deleting a non-existing UAR fails, without throwing an exception
    clear_events();
    clear_log();
    my $factory = Socialtext::UserAccountRoleFactory->instance();
    my $rc      = $factory->Delete($uar);
    ok !$rc, 'cannot delete a non-existing UAR';

    # and that *NO* Event was recorded
    is_event_count(0);

    # and that *NO* entry was logged
    logged_not_like 'info', qr/ACCOUNT_ROLE/, '... NO removal was logged';
}

###############################################################################
# TEST: ByUserId 
by_user_id: {
    # Adds user to a default account.
    my $user        = create_test_user();

    my $default     = Socialtext::Account->Default();
    my $account_one = create_test_account_bypassing_factory();
    my $account_two = create_test_account_bypassing_factory();

    # Add user to accounts.
    Socialtext::UserAccountRoleFactory->Create( {
        user_id    => $user->user_id,
        account_id => $account_one->account_id,
    } );

    Socialtext::UserAccountRoleFactory->Create( {
        user_id    => $user->user_id,
        account_id => $account_two->account_id,
    } );

    my $accounts = Socialtext::UserAccountRoleFactory->ByUserId( $user->user_id );

    isa_ok $accounts, 'Socialtext::MultiCursor', 'Got a list';
    is $accounts->count, 3, '... of correct size';
    
    my $q_account_one = $accounts->next();
    isa_ok $q_account_one, 'Socialtext::UserAccountRole', 'Got account';
    is $q_account_one->account_id, $default->account_id, '... with default account_id';

    my $q_account_one = $accounts->next();
    isa_ok $q_account_one, 'Socialtext::UserAccountRole', 'Got account';
    is $q_account_one->account_id, $account_one->account_id, '... with right account_id';

    my $q_account_two = $accounts->next();
    isa_ok $q_account_two, 'Socialtext::UserAccountRole', 'Got account';
    is $q_account_two->account_id, $account_two->account_id, '... with right account_id';
}

################################################################################
# TEST: ByUserId -- passing in a closure.
by_user_id_with_closure: {
    # Adds user to the Default account.
    my $user = create_test_user();

    my $default     = Socialtext::Account->Default();
    my $account_one = create_test_account_bypassing_factory();
    my $account_two = create_test_account_bypassing_factory();

    # Add user to accounts.
    Socialtext::UserAccountRoleFactory->Create( {
        user_id    => $user->user_id,
        account_id => $account_one->account_id,
    } );

    Socialtext::UserAccountRoleFactory->Create( {
        user_id    => $user->user_id,
        account_id => $account_two->account_id,
    } );

    my $accounts = Socialtext::UserAccountRoleFactory->ByUserId( 
        $user->user_id,
        sub { shift->account(); },
    );

    isa_ok $accounts, 'Socialtext::MultiCursor', 'Got a list';
    is $accounts->count, 3, '... of correct size';
    
    my $q_account_one = $accounts->next();
    isa_ok $q_account_one, 'Socialtext::Account', 'Got account';
    is $q_account_one->name, $default->name, 
        '... with right name';

    my $q_account_one = $accounts->next();
    isa_ok $q_account_one, 'Socialtext::Account', 'Got account';
    is $q_account_one->name, $account_one->name, 
        '... with right name';

    my $q_account_two = $accounts->next();
    isa_ok $q_account_two, 'Socialtext::Account', 'Got account';
    is $q_account_two->name, $account_two->name, 
        '... with right name';
}

################################################################################
# TEST: ByUserId with non-existing user_id
by_user_id_with_non_existing_user_id: {
    my $accounts = Socialtext::UserAccountRoleFactory->ByUserId( 12345678 );

    isa_ok $accounts, 'Socialtext::MultiCursor', 'Got a list';
    ok !$accounts->count(), '... with no results';
}

################################################################################
# TEST: ByAccountId 
by_account_id: {
    my $account  = create_test_account_bypassing_factory();
    my $user_one = create_test_user();
    my $user_two = create_test_user();

    # Create UARs
    Socialtext::UserAccountRoleFactory->Create( {
        user_id    => $user_one->user_id,
        account_id => $account->account_id,
    } );

    Socialtext::UserAccountRoleFactory->Create( {
        user_id    => $user_two->user_id,
        account_id => $account->account_id,
    } );

    my $users = Socialtext::UserAccountRoleFactory->ByAccountId( $account->account_id );
    isa_ok $users, 'Socialtext::MultiCursor', 'Got a list of results';
    is $users->count(), 2, '... of correct size';

    my $q_user_one = $users->next();
    isa_ok $q_user_one, 'Socialtext::UserAccountRole', 'First result';
    is $q_user_one->user_id, $user_one->user_id, '... with correct user_id';

    my $q_user_two = $users->next();
    isa_ok $q_user_two, 'Socialtext::UserAccountRole', 'Second result';
    is $q_user_two->user_id, $user_two->user_id, '... with correct user_id';
}

################################################################################
# TEST: ByAccountId -- passing in a closure.
by_account_id_with_closure: {
    my $account  = create_test_account_bypassing_factory();
    my $user_one = create_test_user();
    my $user_two = create_test_user();

    # Create UARs
    Socialtext::UserAccountRoleFactory->Create( {
        user_id  => $user_one->user_id,
        account_id => $account->account_id,
    } );

    Socialtext::UserAccountRoleFactory->Create( {
        user_id  => $user_two->user_id,
        account_id => $account->account_id,
    } );

    my $users = Socialtext::UserAccountRoleFactory->ByAccountId( 
        $account->account_id,
        sub { shift->user(); }
    );
    isa_ok $users, 'Socialtext::MultiCursor', 'Got a list of results';
    is $users->count(), 2, '... of correct size';

    my $q_user_one = $users->next();
    isa_ok $q_user_one, 'Socialtext::User', 'First result';
    is $q_user_one->username, $user_one->username, '... with correct username';

    my $q_user_two = $users->next();
    isa_ok $q_user_two, 'Socialtext::User', 'Second result';
    is $q_user_two->username, $user_two->username, '... with correct username';
}

################################################################################
# TEST: ByAccountId with non-existing account_id
by_account_id_with_non_existing_account_id: {
    my $uars = Socialtext::UserAccountRoleFactory->ByAccountId( 12345678 );

    isa_ok $uars, 'Socialtext::MultiCursor', 'Got a list';
    ok !$uars->count(), '... with no results';
}
