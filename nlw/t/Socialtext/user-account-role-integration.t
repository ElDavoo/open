#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;

use Socialtext::Workspace;
use Socialtext::UserMetadata;
use Socialtext::UserAccountRoleFactory;
use Test::Socialtext tests => 17;

fixtures(qw( db ));

# We'll need these in all our tests.
my $factory = Socialtext::UserAccountRoleFactory->instance();

################################################################################
create_user_in_default_account: {
    my $account = Socialtext::Account->Default;
    my $user = create_test_user( account => $account );

    my $uar = $factory->Get(
        user_id    => $user->user_id,
        account_id => $account->account_id,
    );

    ok $uar, 'User has role in default account';
}

################################################################################
user_in_non_default_account: {
    my $default = Socialtext::Account->Default;
    my $account = create_test_account_bypassing_factory();
    my $user    = create_test_user(account => $account);

    my $uar = $factory->Get(
        user_id    => $user->user_id,
        account_id => $account->account_id,
    );

    ok $uar, 'User has role in non-default account';

    my $non_uar = $factory->Get(
        user_id    => $user->user_id,
        account_id => $default->account_id,
    );

    ok !$non_uar, 'User has no role in default account';
}

################################################################################
change_user_account: {
    my $old_account = create_test_account_bypassing_factory();
    my $new_account = create_test_account_bypassing_factory();
    my $user        = create_test_user(account => $old_account);
    my $member      = Socialtext::Role->Member();

    my $uar = $factory->Get(
        user_id    => $user->user_id,
        account_id => $old_account->account_id,
    );

    ok $uar, 'User has role in account 1';

    $user->primary_account( $new_account->account_id );
    is $user->primary_account->account_id, $new_account->account_id,
        'primary account updated.';

    my $old_uar = $factory->Get(
        user_id    => $user->user_id,
        account_id => $old_account->account_id,
    );

    ok $old_uar, 'User still has role in old account';
    is $old_uar->role_id, $member->role_id, '... role is member';


    my $new_uar = $factory->Get(
        user_id    => $user->user_id,
        account_id => $new_account->account_id,
    );

    ok $new_uar, 'User has role in new account';
}

################################################################################
user_with_secondary_account: {
    my $primary   = create_test_account_bypassing_factory();
    my $secondary = create_test_account_bypassing_factory();
    my $user      = create_test_user( account => $primary );
    my $ws        = create_test_workspace( account => $secondary );

    # Add user to workspace/secondary account
    $ws->add_user( user => $user );

    my $primary_uar = $factory->Get(
        user_id    => $user->user_id,
        account_id => $primary->account_id,
    );
    ok $primary_uar, 'user is in primary account';

    my $secondary_uar = $factory->Get(
        user_id    => $user->user_id,
        account_id => $secondary->account_id,
    );
    ok $secondary_uar, 'user is in secondary account';

    # Remove user to workspace/secondary account
    $ws->remove_user( user => $user );

    $primary_uar = $factory->Get(
        user_id    => $user->user_id,
        account_id => $primary->account_id,
    );
    ok $primary_uar, 'user is still in primary account';

    $secondary_uar = $factory->Get(
        user_id    => $user->user_id,
        account_id => $secondary->account_id,
    );
    ok !$secondary_uar, 'user is no longer in secondary account';
}

################################################################################
workspace_changes_account: {
    my $primary   = create_test_account_bypassing_factory();
    my $secondary = create_test_account_bypassing_factory();
    my $other     = create_test_account_bypassing_factory();
    my $user      = create_test_user( account => $primary );
    my $ws        = create_test_workspace( account => $secondary );
    
    $ws->add_user( user => $user );

    my $primary_uar = $factory->Get(
        user_id    => $user->user_id,
        account_id => $primary->account_id,
    );
    ok $primary_uar, 'user is in primary account';

    my $secondary_uar = $factory->Get(
        user_id    => $user->user_id,
        account_id => $secondary->account_id,
    );
    ok $secondary_uar, 'user is in secondary account';

    $ws->update( account_id => $other->account_id );

    $primary_uar = $factory->Get(
        user_id    => $user->user_id,
        account_id => $primary->account_id,
    );
    ok $primary_uar, 'user is still in primary account';

    $secondary_uar = $factory->Get(
        user_id    => $user->user_id,
        account_id => $secondary->account_id,
    );
    ok !$secondary_uar, 'user is no longer in secondary account';
    
    my $other_uar = $factory->Get(
        user_id    => $user->user_id,
        account_id => $other->account_id,
    );
    ok $other_uar, 'user is now in other account';
}
