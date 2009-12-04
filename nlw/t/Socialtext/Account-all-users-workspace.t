#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 51;
use Test::Exception;
use Test::Warn;

use Socialtext::User;
use Socialtext::Role;

################################################################################
# Fixtures: db
# - Need a DB around, but don't care what's in it
fixtures(qw( db ));

use_ok 'Socialtext::Account';

################################################################################
# TEST: Set all_users_workspace
set_all_users_workspace: {
    my $acct = create_test_account_bypassing_factory();
    my $ws   = create_test_workspace(account => $acct);

    # update the all_users_workspace
    $acct->update( all_users_workspace => $ws->workspace_id );

    is $acct->all_users_workspace, $ws->workspace_id, 
        'Set all users workspace.';
}

################################################################################
# TEST: Set all_users_workspace, workspace does not exist
set_workspace_does_not_exist: {
    my $acct = create_test_account_bypassing_factory();

    dies_ok {
        $acct->update( all_users_workspace => '-2000' );
    } 'dies when workspace does not exist';

    is $acct->all_users_workspace, undef, '... all users workspace not updated';
}

################################################################################
# TEST: Set all_users_workspace, workspace not in account
set_workspace_not_in_account: {
    my $acct = create_test_account_bypassing_factory();
    my $ws   = create_test_workspace();

    dies_ok {
        $acct->update( all_users_workspace => $ws->workspace_id );
    } 'dies when workspace is not in account';

    is $acct->all_users_workspace, undef, '... all users workspace not updated';
}

################################################################################
# TEST: Add user to account no all users workspace.
account_no_workspace: {
    my $acct = create_test_account_bypassing_factory();
    my $ws   = create_test_workspace(account => $acct);
    my $user = create_test_user(account => $acct);

    my $ws_users = $ws->users;
    isa_ok $ws_users, 'Socialtext::MultiCursor';
    is $ws_users->count, 0, '... with no users';
}

################################################################################
# TEST: add user to all users workspace, not in account
user_not_in_account: {
    my $other_acct = create_test_account_bypassing_factory();
    my $acct       = create_test_account_bypassing_factory();
    my $ws         = create_test_workspace(account => $acct);
    my $user       = create_test_user();

    my $ws_users = $ws->users;
    isa_ok $ws_users, 'Socialtext::MultiCursor';
    is $ws_users->count, 0, '... starts with 0 users';

    # Make the workspace the all account workspace.
    $acct->update( all_users_workspace => $ws->workspace_id );

    # fails silently, user cannot be added to the AUW (using this API)
    # if they do not already have a role in the account.
    # User still can be added with $ws->add_user(), a 'legal' way of doing
    # this.
    $acct->add_to_all_users_workspace( object => $user );

    $ws_users = $ws->users;
    isa_ok $ws_users, 'Socialtext::MultiCursor';
    is $ws_users->count, 0, '... with no users';
}

################################################################################
# TEST: Add/Remove user to account with all users workspace ( high level ).
account_with_workspace_high_level: {
    my $other_acct = create_test_account_bypassing_factory();
    my $acct       = create_test_account_bypassing_factory();
    my $ws         = create_test_workspace(account => $acct);

    # Make the workspace the all account workspace.
    $acct->update( all_users_workspace => $ws->workspace_id );

    # Make sure the user is in the account.
    my $user = create_test_user();
    $user->primary_account( $acct );

    my $ws_users = $ws->users;
    isa_ok $ws_users, 'Socialtext::MultiCursor';
    is $ws_users->count, 1, '... with one user';
    
    my $ws_user = $ws_users->next();
    is $ws_user->username, $user->username, '... who is the correct user';

    # Change user's primary account
    $user->primary_account( $other_acct );
}

################################################################################
# TEST: user is added when all users workspace changes
account_with_workspace_high_level: {
    my $acct = create_test_account_bypassing_factory();
    my $ws   = create_test_workspace(account => $acct);
    my $user = create_test_user(account => $acct);

    # Make the workspace the all account workspace.
    $acct->update( all_users_workspace => $ws->workspace_id );

    my $ws_users = $ws->users;
    isa_ok $ws_users, 'Socialtext::MultiCursor';
    is $ws_users->count, 1, '... with one user';
}

################################################################################
# TEST: all users workspace changes, user stays in ws.
user_remains: {
    my $acct     = create_test_account_bypassing_factory();
    my $ws       = create_test_workspace(account => $acct);
    my $other_ws = create_test_workspace(account => $acct);

    # Make the workspace the all account workspace.
    $acct->update( all_users_workspace => $ws->workspace_id );

    # Make sure the user is in the account.
    my $user = create_test_user();
    $user->primary_account( $acct );

    my $ws_users = $ws->users;
    isa_ok $ws_users, 'Socialtext::MultiCursor';
    is $ws_users->count, 1, '... with one user';

    # Change account's all users workspace.
    $acct->update( all_users_workspace => $other_ws->workspace_id );

    $ws_users = $ws->users;
    isa_ok $ws_users, 'Socialtext::MultiCursor';
    is $ws_users->count, 1, '... still with one user';
}

################################################################################
user_primary_account_change: {
    my $old_acct = create_test_account_bypassing_factory();
    my $old_ws   = create_test_workspace(account => $old_acct);
    my $new_acct = create_test_account_bypassing_factory();
    my $new_ws   = create_test_workspace(account => $new_acct);
    my $member   = Socialtext::Role->Member();

    $old_acct->update( all_users_workspace => $old_ws->workspace_id );
    is $old_acct->all_users_workspace, $old_ws->workspace_id,
        'old Account has all users workspace';

    $new_acct->update( all_users_workspace => $new_ws->workspace_id );
    is $new_acct->all_users_workspace, $new_ws->workspace_id,
        'new Account has all users workspace';

    my $user = create_test_user( account => $old_acct );

    # make sure User is in all users Workspace
    my $role = $old_ws->role_for_user($user);
    ok $role, 'User has Role in old all users Workspace';
    is $role->role_id, $member->role_id, '... Role is member';

    # Update the User's primary Account
    $user->primary_account( $new_acct );
    is $user->primary_account_id, $new_acct->account_id,
       'User is in new primary Account';

    # make sure User is in new all users Workspace
    $role = $new_ws->role_for_user($user);
    ok $role, 'User has Role in new all users Workspace';
    is $role->role_id, $member->role_id, '... Role is member';

    # make sure User is still in the _old_ all users Workspace
    $role = $old_ws->role_for_user($user);
    ok $role, 'User still has Role in old all users Workspace';
    is $role->role_id, $member->role_id, '... Role is member';
}

################################################################################
user_with_indirect_account_role: {
    my $user   = create_test_user();
    my $acct   = create_test_account_bypassing_factory();
    my $auw    = create_test_workspace(account => $acct);
    my $ws     = create_test_workspace(account => $acct);
    my $member = Socialtext::Role->Member();

    $acct->update( all_users_workspace => $auw->workspace_id );
    is $acct->all_users_workspace, $auw->workspace_id,
        'Account has all users workspace';

    # Give user an indirect role in the Account by adding them to a (non-AUW)
    # workspace
    $ws->add_user( user => $user, role => $member );

    # Verify the the User has a Role in the Account
    my $role = $acct->role_for_user($user);
    ok $role, 'User has Role in Account';

    # User was also added to all users Workspace
    $role = $auw->role_for_user($user);
    ok $role, 'User has Role in all users Workspace';
    is $role->role_id, $member->role_id, '... Role is member';
}

################################################################################
group_has_role_in_auw_exists: {
    my $acct   = create_test_account_bypassing_factory();
    my $ws     = create_test_workspace(account => $acct);
    my $group  = create_test_group(account => $acct);
    my $user   = create_test_user();
    my $member = Socialtext::Role->Member();

    # Update AUW _before_ adding the group.
    $acct->update( all_users_workspace => $ws->workspace_id );
    is $acct->all_users_workspace, $ws->workspace_id,
        'Account assigned all users workspace before adding groups';

    # Add User to Group
    $group->add_user( user => $user );
    my $role = $group->role_for_user($user);
    ok $role, 'User has Role in Group';
    is $role->role_id, $member->role_id, '... Role is Member';

    # Check User's Role in the AUW
    $role = $ws->role_for_user($user, direct => 1 );
    ok !$role, 'User does _not_ have a direct Role in AUW';

    $role = $ws->role_for_user($user);
    ok $role, 'User has an indirect Role in AUW';
}

################################################################################
group_has_role_in_auw_updated: {
    my $acct   = create_test_account_bypassing_factory();
    my $ws     = create_test_workspace(account => $acct);
    my $group  = create_test_group(account => $acct);
    my $user   = create_test_user();
    my $member = Socialtext::Role->Member();

    # Add User to Group
    $group->add_user( user => $user );
    my $role = $group->role_for_user($user);
    ok $role, 'User has Role in Group';
    is $role->role_id, $member->role_id, '... Role is Member';

    # Update the AUW _after_ adding the group.
    $acct->update( all_users_workspace => $ws->workspace_id );
    is $acct->all_users_workspace, $ws->workspace_id,
        'Account has all users workspace updated after adding groups';

    # Check User's Role in the AUW
    $role = $ws->role_for_user($user, direct => 1 );
    ok !$role, 'User does _not_ have a direct Role in AUW';

    $role = $ws->role_for_user($user);
    ok $role, 'User has an indirect Role in AUW';
}

################################################################################
group_has_role_in_auw_when_added_to_account: {
    my $acct   = create_test_account_bypassing_factory();
    my $ws     = create_test_workspace(account => $acct);
    my $group  = create_test_group();
    my $user   = create_test_user();
    my $member = Socialtext::Role->Member();

    $acct->update( all_users_workspace => $ws->workspace_id );
    is $acct->all_users_workspace, $ws->workspace_id,
        'Account has all users workspace updated after adding groups';

    # Add User to Group
    $group->add_user( user => $user );
    my $role = $group->role_for_user($user);
    ok $role, 'User has Role in Group';
    is $role->role_id, $member->role_id, '... Role is Member';

    # Add Group to Account
    $acct->add_group( group => $group );
    ok $acct->has_group( $group ), 'Group is added to Account';
    ok $acct->has_user( $user ), 'User is added to Account';

    # Check User's Role in the AUW
    $role = $ws->role_for_user($user, direct => 1 );
    ok !$role, 'User does _not_ have a direct Role in AUW';

    $role = $ws->role_for_user($user);
    ok $role, 'User has an indirect Role in AUW';
}
