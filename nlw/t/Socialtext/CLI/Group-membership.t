#!/usr/bin/perl
use strict;
use warnings;

use Socialtext::GroupAccountRoleFactory;
use Test::Socialtext qw(no_plan);
use Test::Output qw(combined_from);

# Only need a DB.
fixtures(qw(db));

use_ok 'Socialtext::CLI';

###############################################################################
# over-ride "_exit", so we can capture the exit code
our $LastExitVal;
{
    no warnings 'redefine';
    *Socialtext::CLI::_exit = sub { $LastExitVal=shift; };
}

################################################################################
# TEST: add group to account
add_group_to_account: {
    my $group   = create_test_group();
    my $account = create_test_account_bypassing_factory();

    ok 1, 'Group is added to Account';
    my $output = combined_from( sub {
        Socialtext::CLI->new(
            argv => [
                    '--group'   => $group->group_id,
                    '--account' => $account->name,
                ],
        )->add_member();
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
        Socialtext::CLI->new(
            argv => [
                    '--group'   => $group->group_id,
                    '--account' => $account->name,
            ],
        )->add_member();
    } );
    like $output, qr/Group \(.+\) is already a member of Account \(.+\)/,
        '... with correct message';
}

################################################################################
# TEST: remove Group from Account
remove_group_from_account: {
    my $account = create_test_account_bypassing_factory();
    my $group   = create_test_group( account => $account );

    ok 1, 'Remove Group from Account';
    my $output = combined_from( sub {
        Socialtext::CLI->new(
            argv => [
                '--group'   => $group->group_id,
                '--account' => $account->name,
            ],
        )->remove_member();
    } );

    like $output, qr/Group \(.+\) has been removed from Account \(.+\)/,
        '... with correct message';
    is $account->has_group( $group ) => 0, '... group is no longer in account';
}

################################################################################
# TEST: remove Group from Account, Group is not in Account
group_is_not_in_account: {
    my $account = create_test_account_bypassing_factory();
    my $group   = create_test_group();

    ok 1, 'Remove Group that is not in Account';
    my $output = combined_from( sub {
        Socialtext::CLI->new(
            argv => [
                '--group'   => $group->group_id,
                '--account' => $account->name,
            ],
        )->remove_member();
    } );

    like $output, qr/Group \(.+\) is not a member of Account \(.+\)/,
        '... with correct message';
}
