#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;

use Socialtext::GroupAccountRoleFactory;
use Test::Socialtext tests => 41;
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

################################################################################
# TEST: add group to account
add_group_to_account: {
    my $group   = create_test_group();
    my $account = create_test_account_bypassing_factory();

    ok 1, 'Group is added to Account';
    my $output = combined_from( sub {
        eval {
            Socialtext::CLI->new(
                argv => [
                        '--group'   => $group->group_id,
                        '--account' => $account->name,
                    ],
            )->add_member();
        };
    } );
    like $output, qr/Group \(.+\) has been added to Account \(.+\)/,
        '... with correct message';

    my $gar = Socialtext::GroupAccountRoleFactory->Get(
        group_id => $group->group_id,
        account_id => $account->account_id,
    );
    isa_ok $gar => 'Socialtext::GroupAccountRole';
    is $gar->group_id => $group->group_id,
        '... with correct group';
    is $gar->account_id => $account->account_id,
        '... with correct account';
    is $gar->role_id => Socialtext::Role->Member()->role_id,
       '... with correct role';
}

################################################################################
# TEST: add group to account, group already exists
group_already_exists: {
    my $account = create_test_account_bypassing_factory();
    my $group = create_test_group( account => $account );

    ok 1, 'Group is not added to Account';
    my $output = combined_from( sub {
        eval {
            Socialtext::CLI->new(
                argv => [
                        '--group'   => $group->group_id,
                        '--account' => $account->name,
                ],
            )->add_member();
        };
    } );
    like $output, qr/Group \(.+\) is already a member of Account \(.+\)/,
        '... with correct message';
}

################################################################################
# TEST: remove Group from Account
remove_group_from_account: {
    my $account = create_test_account_bypassing_factory();
    my $group   = create_test_group();

    $account->add_group(group => $group);

    ok 1, 'Remove Group from Account';
    my $output = combined_from( sub {
        eval {
            Socialtext::CLI->new(
                argv => [
                    '--group'   => $group->group_id,
                    '--account' => $account->name,
                ],
            )->remove_member();
        };
    } );

    like $output, qr/Group \(.+\) has been removed from Account \(.+\)/,
        '... with correct message';
    is $account->has_group( $group ) => 0, '... group is no longer in account';
}

################################################################################
# TEST: remove Group from Primary Account
remove_group_from_primary_account: {
    my $account = create_test_account_bypassing_factory();
    my $group   = create_test_group( account => $account );

    $account->add_group(group => $group);

    ok 1, 'Remove Group from Primary Account';
    my $output = combined_from( sub {
        eval {
            Socialtext::CLI->new(
                argv => [
                    '--group'   => $group->group_id,
                    '--account' => $account->name,
                ],
            )->remove_member();
        };
    } );

    like $output, qr/Account .+ is Group's Primary Account/,
        '... with correct error message';
    ok $account->has_group( $group ), '... group is still a member';
}

################################################################################
# TEST: remove Group from Account, Group is not in Account
group_is_not_in_account: {
    my $account = create_test_account_bypassing_factory();
    my $group   = create_test_group();

    ok 1, 'Remove Group that is not in Account';
    my $output = combined_from( sub {
        eval {
            Socialtext::CLI->new(
                argv => [
                    '--group'   => $group->group_id,
                    '--account' => $account->name,
                ],
            )->remove_member();
        };
    } );

    like $output, qr/Group \(.+\) is not a member of Account \(.+\)/,
        '... with correct message';
}

################################################################################
# TEST: Group members are listed in Account membership list
group_users_in_account_membership: {
    my $account = create_test_account_bypassing_factory();
    my $group   = create_test_group( account => $account );
    my $user    = create_test_user();
    my $email   = $user->email_address;

    $group->add_user( user => $user );
    ok $group->has_user( $user ), 'User is in Group';

    $account->add_group( group => $group );
    ok $account->has_group( $group ), 'Group is in Account';

    my $output = combined_from( sub {
        eval {
            Socialtext::CLI->new(
                argv => [
                    '--account' => $account->name,
                ],
            )->show_members();
        };
    } );

    like $output, qr/\Q$email\E/, 'Account lists group user';
}

################################################################################
# TEST: Account users in Groups are de-duped
group_users_in_account_membership_de_duped: {
    my $account = create_test_account_bypassing_factory();
    my $group   = create_test_group( account => $account );
    my $user    = create_test_user( account => $account );
    my $email   = $user->email_address;

    $group->add_user( user => $user );
    ok $group->has_user( $user ), 'User is in Group';

    $account->add_group( group => $group );
    ok $account->has_group( $group ), 'Group is in Account';

    my $output = combined_from( sub {
        eval {
            Socialtext::CLI->new(
                argv => [
                    '--account' => $account->name,
                ],
            )->show_members();
        };
    } );

    my @lines = grep { /\Q$email\E/ } split(/\n/, $output);
    is scalar(@lines), 1, 'Users are de-duped for Account';
}

################################################################################
# TEST: Workspace users in Groups are de-duped
group_users_in_workspace_membership_de_duped: {
    my $workspace = create_test_workspace();
    my $user      = create_test_user();
    my $group     = create_test_group();
    my $email     = $user->email_address;

    $workspace->add_user( user => $user );
    ok $workspace->has_user( $user ), 'User is in Workspace';

    $group->add_user( user => $user );
    ok $group->has_user( $user ), 'User is in Group';

    my $output = combined_from( sub {
        eval {
            Socialtext::CLI->new(
                argv => [
                    '--workspace' => $workspace->name,
                ],
            )->show_members();
        };
    } );

    my @lines = grep { /\Q$email\E/ } split(/\n/, $output);
    is scalar(@lines), 1, 'Users are de-duped for Workspace';
}

################################################################################
# TEST: Account users in Groups are not displayed
group_users_in_account_membership_no_displayed: {
    my $account = create_test_account_bypassing_factory();
    my $group   = create_test_group( account => $account );

    my $user1  = create_test_user();
    my $email1 = $user1->email_address;
    $group->add_user( user => $user1 );
    ok $group->has_user( $user1 ), 'User is in Group';

    $account->add_group( group => $group );
    ok $account->has_group( $group ), 'Group is in Account';

    # create another user with a _direct_ account membership
    my $user2 = create_test_user( account => $account );
    my $email2 = $user2->email_address;

    ok 1, 'All Account Users';
    my $output = combined_from( sub {
        eval {
            Socialtext::CLI->new(
                argv => [
                    '--account' => $account->name,
                ],
            )->show_members();
        };
    } );
    like $output, qr/\Q$email1\E/, '... lists group user';
    like $output, qr/\Q$email2\E/, '... lists direct user';

    ok 1, 'Direct Account Users';
    $output = combined_from( sub {
        eval {
            Socialtext::CLI->new(
                argv => [
                    '--account' => $account->name,
                    '--direct',
                ],
            )->show_members();
        };
    } );
    unlike $output, qr/\Q$email1\E/, '... does not list group user';
    like $output, qr/\Q$email2\E/, '... lists direct user';
}

################################################################################
# TEST: Workspace Users with direct Roles
workspace_users_with_direct_roles: {
    my $workspace = create_test_workspace();
    my $group     = create_test_group();
    my $user1     = create_test_user();
    my $email1    = $user1->email_address;
    my $user2     = create_test_user();
    my $email2    = $user2->email_address;

    $group->add_user( user => $user1 );
    ok $group->has_user( $user1 ), 'User1 is in Group';

    $workspace->add_user( user => $user2 );
    ok $workspace->has_user( $user2 ), 'User2 is in Workspace';

    $workspace->add_group( group => $group );
    ok $workspace->has_group( $group ), 'Group is in Workspace';

    my $output = combined_from( sub {
        eval {
            Socialtext::CLI->new(
                argv => [
                    '--workspace' => $workspace->name,
                ],
            )->show_members();
        }
    } );
    like $output, qr/\Q$email1\E/, '... lists group user without direct';
    like $output, qr/\Q$email2\E/, '... lists direct user without direct';

    $output = combined_from( sub {
        eval {
            Socialtext::CLI->new(
                argv => [
                    '--workspace' => $workspace->name,
                    '--direct',
                ],
            )->show_members();
        };
    } );

    unlike $output, qr/\Q$email1\E/, '... does not list group user with direct';
    like $output, qr/\Q$email2\E/, '... lists direct user with direct';
}
