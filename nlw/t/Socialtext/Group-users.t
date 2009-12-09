#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 48;
use Test::Exception;
use List::MoreUtils qw/all none/;
use Scalar::Util qw/blessed/;

################################################################################
# Fixtures: db
# - need a DB, but don't care what's in it.
fixtures(qw( db ));

use_ok 'Socialtext::Group';

my $Member = Socialtext::Role->Member;
my $Member_id = $Member->role_id;
my $Admin = Socialtext::Role->Admin;
my $Admin_id = $Admin->role_id;

################################################################################
# NOTE: this behaviour is more extensively tested in
# t/Socialtext/UserGroupRoleFactory.t
################################################################################

################################################################################
# TEST: Group has no Users; it's a lonely, lonely group.
group_with_no_users: {
    my $group = create_test_group();
    my $users = $group->users();

    isa_ok $users, 'Socialtext::MultiCursor', 'got a list of users';
    is $users->count(), 0, '... with the correct count';
}

################################################################################
# TEST: Group has some Users
group_has_users: {
    my $group    = create_test_group();
    my $user_one = create_test_user();
    my $user_two = create_test_user();

    $group->add_user(user => $user_one);
    $group->add_user(user => $user_two);

    my $users = $group->users();
    isa_ok $users, 'Socialtext::MultiCursor', 'got a list of users';
    is $users->count(), 2, '... with the correct count';
    isa_ok $users->next(), 'Socialtext::User', '... queried User';
}

################################################################################
# TEST: Group has some Users, get their User Ids
group_has_users_get_user_ids: {
    my $group    = create_test_group();
    my $user_one = create_test_user();
    my $user_two = create_test_user();

    $group->add_user(user => $user_one);
    $group->add_user(user => $user_two);

    my $user_ids = $group->user_ids();
    is_deeply $user_ids, [ $user_one->user_id, $user_two->user_id ],
        'Got User Ids, in correct order';
}

################################################################################
# TEST: Add User to Group with default Role
add_user_to_group_with_default_role: {
    my $group = create_test_group();
    my $user  = create_test_user();

    # Group should be empty (have no Users)
    is $group->users->count(), 0, 'Group has no Users in it (yet)';

    # Add the User to the Group
    $group->add_user(user => $user);

    # Make sure the User got added properly
    is $group->users->count(), 1, '... added User to Group';

    # Make sure User was given the default Role
    my $default_role = Socialtext::Role->Member;
    my $users_role   = $group->role_for_user($user);
    is $users_role->role_id, $default_role->role_id,
        '... with Default UGR Role';
}

###############################################################################
# TEST: Add User to Group with explicit Role
add_user_to_group_with_role: {
    my $group = create_test_group();
    my $user  = create_test_user();
    my $role  = Socialtext::Role->Admin();

    # Group should be empty (have no Users)
    is $group->users->count(), 0, 'Group has no Users in it (yet)';

    # Add the User to the Group
    $group->add_user(user => $user, role => $role);

    # Make sure the User got added properly
    is $group->users->count(), 1, '... added User to Group';

    # Make sure User has correct Role
    my $users_role   = $group->role_for_user($user);
    is $users_role->role_id, $role->role_id, '... with provided Role';
}

###############################################################################
# TEST: Update User's Role in Group
update_users_role_in_group: {
    my $group = create_test_group();
    my $user  = create_test_user();
    my $role  = Socialtext::Role->Admin();

    # Add the User to the Group, with Default Role
    $group->add_user(user => $user);

    # Make sure the User was given the Default Role
    my $default_role = Socialtext::Role->Member;
    my $users_role   = $group->role_for_user($user);
    is $users_role->role_id, $default_role->role_id,
        'User has default Role in Group';

    # Update the User's Role
    $group->assign_role_to_user(user => $user, role => $role);

    # Make sure User had their Role updated
    $users_role = $group->role_for_user($user);
    is $users_role->role_id, $role->role_id, '... Role was updated';
}

###############################################################################
# TEST: Get the Role for a User
get_role_for_user: {
    my $group = create_test_group();
    my $user  = create_test_user();

    # Add the User to the Group
    $group->add_user(user => $user);

    # Get the Role for the User
    my $role = $group->role_for_user($user);
    isa_ok $role, 'Socialtext::Role', 'queried Role';
}

###############################################################################
# TEST: Does this User have a Role in the Group
does_group_have_user: {
    my $group = create_test_group();
    my $user  = create_test_user();

    # Group should not (yet) have this User
    ok !$group->has_user($user), 'User does not yet have Role in Group';

    # Add the User to the Group
    $group->add_user(user => $user);

    # Now the User is in the Group
    ok $group->has_user($user), '... but has now been added';
}

###############################################################################
# TEST: Remove User from Group
remove_user_from_group: {
    my $group = create_test_group();
    my $user  = create_test_user();

    # Group should be empty to start
    ok !$group->has_user($user), 'User does not yet have Role in Group';

    # Add the User to the Group
    $group->add_user(user => $user);
    ok $group->has_user($user), '... User has been added to Group';

    # Remove the User from the Group
    $group->remove_user(user => $user);
    ok !$group->has_user($user), '... User has been removed from Group';
}

###############################################################################
# TEST: Remove User from Group, when they have *no* Role in that Group
remove_non_member_user_from_group: {
    my $group = create_test_group();
    my $user  = create_test_user();

    # Group should be empty to start
    ok !$group->has_user($user), 'User does not have Role in Group';

    # Removing a non-member User from the Group shouldn't choke.  No errors,
    # no warnings, no fatal exceptions... its basically a no-op
    lives_ok { $group->remove_user(user => $user) }
        "... removing non-member User from Group doesn't choke";
}

ok $Member_id < $Admin_id, "admin comes after member";
sorted_users: {
    my $group = create_test_group();
    my $user1 = create_test_user(unique_id => "ZZZ$^T");
    my $uid1 = $user1->user_id;
    $group->add_user(user => $user1);
    my $user2 = create_test_user(unique_id => "AAA$^T");
    my $uid2 = $user2->user_id;
    $group->add_user(user => $user2);
    my $user3 = create_test_user(unique_id => "MMM$^T");
    my $uid3 = $user3->user_id;
    $group->add_user(user => $user3);

    # nested
    my $group2 = create_test_group();
    $group->add_group(group => $group2, role => 'admin');

    # an indirect+direct user
    my $user4 = create_test_user(unique_id => "JJJ$^T");
    my $uid4 = $user4->user_id;
    $group2->add_user(user => $user4, role => 'admin');
    $group->add_user(user => $user4, role => 'member');

    # an indirect-only user
    my $user5 = create_test_user(unique_id => "PPP$^T");
    my $uid5 = $user5->user_id;
    $group2->add_user(user => $user5, role => 'admin');

    my $cursor = $group->sorted_user_roles(
        order_by => 'username',
        sort_order => 'asc',
        raw => 1,
        direct => 1,
    );
    is $cursor->count, 4;
    my @all = $cursor->all();
    is_deeply [ map {$_->{user_id}} @all ], [$uid2,$uid4,$uid3,$uid1];
    ok none(sub { exists $_->{user} }, @all), "no user objects";
    ok none(sub { exists $_->{role} }, @all), "no role objects";
    ok all(sub { $_->{role_id} == $Member->role_id }, @all), "all members";
    ok none(sub { $_->{user_id} == $uid5 }, @all), "indirect-only user excluded";

    $cursor = $group->sorted_user_roles(
        order_by => 'username',
        sort_order => 'asc',
        raw => 1,
    );
    is $cursor->count, 6;
    @all = $cursor->all();
    ok none(sub { exists $_->{user} }, @all), "no user objects";
    ok none(sub { exists $_->{role} }, @all), "no role objects";
    is_deeply [ map {$_->{user_id}} @all ], [
        $uid2,$uid4,$uid4,$uid3,$uid5,$uid1];
    is_deeply [ map {$_->{role_id}} @all ], [
        $Member_id,$Member_id,$Admin_id,$Member_id,$Admin_id,$Member_id];

    $cursor = $group->sorted_user_roles(
        order_by => 'role_name',
        sort_order => 'asc',
        raw => 1,
    );
    is $cursor->count, 6;
    @all = $cursor->all();
    ok none(sub { exists $_->{user} }, @all), "no user objects";
    ok none(sub { exists $_->{role} }, @all), "no role objects";
    is_deeply [ map {$_->{role_id}} @all ], [
        ($Admin_id) x 2, ($Member_id) x 4], 'role_name major sort';
    is_deeply [ map {$_->{user_id}} @all ], [
        $uid4,$uid5,$uid1,$uid2,$uid3,$uid4], 'uids minor sort';

    $cursor = $group->sorted_user_roles(
        order_by => 'username',
        sort_order => 'desc',
        direct => 1,
    );
    is $cursor->count, 4;
    @all = $cursor->all();
    ok all(sub { blessed $_->{user} }, @all), "lots of user objects";
    ok all(sub { blessed $_->{role} }, @all), "lots of role objects";
    is_deeply [ map {$_->{user}->user_id} @all ], [$uid1,$uid3,$uid4,$uid2],
        "mapped by user_id method";

    $cursor = $group->sorted_user_roles(
        order_by => 'source',
        sort_order => 'desc',
        raw => 1,
    );
    is $cursor->count, 6;
    @all = $cursor->all();
    ok none(sub { exists $_->{user} }, @all), "no user objects";
    ok none(sub { exists $_->{role} }, @all), "no role objects";
    is_deeply [ map {$_->{user_id}} @all ], [
        $uid1,$uid2,$uid3,$uid4,$uid4,$uid5], 'uids minor sort; all same source';
}
