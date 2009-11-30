#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::Socialtext tests => 16;
use Test::Output qw(combined_from);

# Only need a DB.
fixtures(qw(db));

use_ok 'Socialtext::CLI';

###############################################################################
# over-ride "_exit", so we can capture the exit code
our $LastExitVal;
{
    no warnings 'redefine';
    *Socialtext::CLI::_exit = sub { $LastExitVal=shift; die; };
}

###############################################################################
add_user_to_group_as_member: {
    my $group = create_test_group();
    my $user  = create_test_user();

    ok !$group->has_user( $user ), 'user is not in group.';
    my $output = combined_from( sub {
        eval {
            Socialtext::CLI->new(
                argv => [
                    '--group' => $group->group_id,
                    '--email' => $user->email_address,
                ],
            )->add_member();
        };
    } );
    like $output, qr/.+ is now a member of the .+ Group/,
         'User added to Group message';

    my $role = $group->role_for_user( user => $user );
    ok $role, 'User has Role in Group';
    is $role->name, Socialtext::Role->Member()->name,
        '... Role is Member';

    # User is already in group, return error.
    $output = combined_from( sub {
        eval {
            Socialtext::CLI->new(
                argv => [
                    '--group' => $group->group_id,
                    '--email' => $user->email_address,
                ],
            )->add_member();
        };
    } );
    like $output, qr/User already has a 'member' role in Group/,
         'User added to Group message';
}

###############################################################################
invalid_add_user_to_group_as_member: {
    my $group = create_test_group();
    my $user  = create_test_user();

    # Invalid Email Address
    is $group->users->count, 0, 'Group has no Users';
    my $output = combined_from( sub {
        eval {
            Socialtext::CLI->new(
                argv => [
                    '--group' => $group->group_id,
                    '--email' => 'nosuchuser@example.com',
                ],
            )->add_member();
        };
    } );
    like $output, qr/No user with the email address .+ could be found/,
         'Invalid User message';
    is $group->users->count, 0, '... Group still has no Users';

    # Invalid Group Id
    $output = combined_from( sub {
        eval {
            Socialtext::CLI->new(
                argv => [
                    '--group' => 0,
                    '--email' => $user->email_address,
                ],
            )->add_member();
        };
    } );
    like $output, qr/No group with ID \d+/,
         'Invalid Group message';
}

###############################################################################
remove_member_from_group: {
    my $group  = create_test_group();
    my $user   = create_test_user();

    $group->add_user( user => $user, role => Socialtext::Role->Member() );
    ok $group->has_user( $user ), 'User is a member of the Group';

    # Remove the user
    my $output = combined_from( sub {
        eval {
            Socialtext::CLI->new(
                argv => [
                    '--group' => $group->group_id,
                    '--email' => $user->email_address,
                ],
            )->remove_member();
        };
    } );
    like $output, qr/.+ is no longer a member of .+/,
         'Got success message';
    ok !$group->has_user( $user ), '... User is no longer in Group';

    # Removing the user again should get an error message
    $output = combined_from( sub {
        eval {
            Socialtext::CLI->new(
                argv => [
                    '--group' => $group->group_id,
                    '--email' => $user->email_address,
                ],
            )->remove_member();
        };
    } );
    like $output, qr/.+ is not a member of .+/,
        'Error trying to remove user again';
}

###############################################################################
invalid_remove_member_from_group: {
    my $group = create_test_group();
    my $user  = create_test_user();

    # Invalid User
    my $output = combined_from( sub {
        eval {
            Socialtext::CLI->new(
                argv => [
                    '--group' => $group->group_id,
                    '--email' => 'nosuchuser@example.com',
                ],
            )->remove_member();
        };
    } );
    like $output, qr/ No user with the email address .+ could be found/,
         'Got no user error message';

    # Invalid Group
    $output = combined_from( sub {
        eval {
            Socialtext::CLI->new(
                argv => [
                    '--group' => 0,
                    '--email' => $user->username,
                ],
            )->remove_member();
        };
    } );
    like $output, qr/No group with ID \d+/,
         'Got no group error message';
}
exit;
