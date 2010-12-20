#!perl

use strict;
use warnings;
use Test::Socialtext tests => 8;

fixtures(qw( db ));

###############################################################################
# Force People Profile Fields to be automatically created, so we don't have to
# set up the default sets of fields from scratch.
$Socialtext::People::Fields::AutomaticStockFields=1;

###############################################################################
# TEST: Can't get a User's Profile if "people" is not enabled
get_profile: {
    my $acct = create_test_account_bypassing_factory();
    my $user = create_test_user(account => $acct);

    my $profile = $user->profile();
    ok !$profile, 'No profile available when People is not enabled.';

    $acct->enable_plugin('people');

    # Refresh User object and verify that the Profile is now available.
    $user = Socialtext::User->new(username => $user->username);
    $profile = $user->profile();
    ok $profile, '... but is available when People is enabled';
}

###############################################################################
# TEST: User's "preferred_name" shows up in their BFN
best_full_name: {
    my $acct = create_test_account_bypassing_factory();
    $acct->enable_plugin('people');

    my $user = create_test_user(
        first_name => 'Davey',
        last_name  => 'Jones',
        account    => $acct,
    );

    my $old_bfn = $user->best_full_name();
    is $old_bfn, 'Davey Jones', 'BFN is FN/LN when no Preferred Name present';

    my $profile = $user->profile();
    $profile->set_attr('preferred_name', 'Bubba Bo Bob Brain');
    $profile->save();

    my $new_bfn = $user->best_full_name();
    is $new_bfn, 'Bubba Bo Bob Brain', 'BFN is Preferred Name when present';
}

###############################################################################
# TEST: User's "preferred_name" shows up in their "guess_real_name"
guess_real_name: {
    my $acct = create_test_account_bypassing_factory();
    $acct->enable_plugin('people');

    my $user = create_test_user(
        first_name => 'Sam',
        last_name  => 'Gamgee',
        account    => $acct,
    );

    my $old_bfn = $user->best_full_name();
    is $old_bfn, 'Sam Gamgee', 'GRN is FN/LN when no Preferred Name present';

    my $profile = $user->profile();
    $profile->set_attr('preferred_name', 'Bubba Bo Bob Brain');
    $profile->save();

    my $bfn = $user->guess_real_name();
    is $bfn, 'Bubba Bo Bob Brain', 'GFN is Preferred Name when present';
}

###############################################################################
# TEST: User's "preferred_name" shows up in their "guess_sortable_name"
guess_sortable_name: {
    my $acct = create_test_account_bypassing_factory();
    $acct->enable_plugin('people');

    my $user = create_test_user(
        first_name => 'Oscar',
        last_name  => 'Peterson',
        account    => $acct,
    );

    my $old_bfn = $user->best_full_name();
    is $old_bfn, 'Oscar Peterson', 'GRN is FN/LN when no Preferred Name present';

    my $profile = $user->profile();
    $profile->set_attr('preferred_name', 'Bubba Bo Bob Brain');
    $profile->save();

    my $bfn = $user->guess_sortable_name();
    is $bfn, 'Bubba Bo Bob Brain', 'Guess Sortable Name contains preferred_name';
}
