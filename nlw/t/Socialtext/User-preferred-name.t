#!perl

use strict;
use warnings;
use Test::Socialtext tests => 11;

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
# TEST: Preferred Name is missing if no People Profile is available
no_preferred_name_when_people_not_enabled: {
    my $acct = create_test_account_bypassing_factory();
    my $user = create_test_user(account => $acct);

    my $name = $user->preferred_name;
    ok !$name, 'No Preferred Name when People is not enabled';
}

###############################################################################
# TEST: Preferred Name is missing if field is hidden
no_preferred_name_when_field_is_hidden: {
    my $acct = create_test_account_bypassing_factory();
    my $user = create_test_user(account => $acct);
    $acct->enable_plugin('people');

    my $profile = $user->profile();
    $profile->set_attr('preferred_name', 'Bubba Bo Bob Brain');
    $profile->save();

    my $adapter = Socialtext::Pluggable::Adapter->new();
    my $plugin  = $adapter->plugin_class('people');
    $plugin->SetProfileField( {
        name      => 'preferred_name',
        is_hidden => 1,
        account   => $acct,
    } );

    my $name = $user->preferred_name;
    ok !$name, 'No Preferred Name when field is hidden';
}

###############################################################################
# TEST: Preferred Name is available in Profile
preferred_name_available: {
    my $acct = create_test_account_bypassing_factory();
    my $user = create_test_user(account => $acct);
    $acct->enable_plugin('people');

    my $profile = $user->profile();
    $profile->set_attr('preferred_name', 'Bubba Bo Bob Brain');
    $profile->save();

    my $name = $user->preferred_name;
    is $name, 'Bubba Bo Bob Brain', 'Preferred Name curries';
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
