#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 18;
use Test::Exception;

###############################################################################
# Fixtures: db
fixtures(qw( admin ));

use_ok 'Socialtext::UserAccountRole';

###############################################################################
# TEST: instantiation
instantiation: {
    my $uar = Socialtext::UserAccountRole->new( {
        user_id  => 1,
        account_id => 2,
        role_id  => 3,
        } );
    isa_ok $uar, 'Socialtext::UserAccountRole';
    is $uar->user_id,  1, '... with the provided user_id';
    is $uar->account_id, 2, '... with the provided account_id';
    is $uar->role_id,  3, '... with the provided role_id';
}

###############################################################################
# TEST: instantiation with additional attributes
instantiation_with_extra_attributes: {
    my $uar;
    lives_ok sub {
        $uar = Socialtext::UserAccountRole->new( {
            user_id  => 1,
            account_id => 2,
            role_id  => 3,
            bogus    => 'attribute',
        } );
    }, 'created UAR when additional attributes provided';
    isa_ok $uar, 'Socialtext::UserAccountRole', '... created UAR';
}

###############################################################################
# TEST: instantiation with actual User/Account/Role
instantiation_with_real_data: {
    my $user    = create_test_user();
    my $account = create_test_account();
    my $role    = Socialtext::Role->new(name => 'member');
    my $uar     = Socialtext::UserAccountRole->new( {
        user_id    => $user->user_id,
        account_id => $account->account_id,
        role_id    => $role->role_id,
        } );
    isa_ok $uar, 'Socialtext::UserAccountRole';

    is $uar->user_id,    $user->user_id,
        '... with the provided user_id';
    is $uar->account_id, $account->account_id,
        '... with the provided account_id';
    is $uar->role_id,    $role->role_id,
        '... with the provided role_id';

    is $uar->user->user_id, $user->user_id,
        '... with the right inflated User object';
    is $uar->account->account_id, $account->account_id,
        '... with the right inflated Account object';
    is $uar->role->role_id, $role->role_id,
        '... with the right inflated Role object';
}

###############################################################################
# TEST: ST::(User|Group|Role) are lazy-loaded
lazy_load_modules: {
    my $loaded = modules_loaded_by('Socialtext::UserAccountRole');
    ok  $loaded->{'Socialtext::UserAccountRole'}, 'ST::UAR loaded';
    ok !$loaded->{'Socialtext::User'},    '... ST::User lazy-loaded';
    ok !$loaded->{'Socialtext::Account'}, '... ST::Account lazy-loaded';
    ok !$loaded->{'Socialtext::Role'},    '... ST::Role lazy-loaded';
}
