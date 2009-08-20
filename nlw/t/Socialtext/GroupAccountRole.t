#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 18;
use Test::Exception;

###############################################################################
# Fixtures: db
fixtures(qw( admin ));

use_ok 'Socialtext::GroupAccountRole';

###############################################################################
# TEST: instantiation
instantiation: {
    my $gar = Socialtext::GroupAccountRole->new( {
        group_id   => 1,
        account_id => 2,
        role_id    => 3,
        } );
    isa_ok $gar, 'Socialtext::GroupAccountRole';
    is $gar->group_id,  1, '... with the provided group_id';
    is $gar->account_id, 2, '... with the provided account_id';
    is $gar->role_id,  3, '... with the provided role_id';
}

###############################################################################
# TEST: instantiation with additional attributes
instantiation_with_extra_attributes: {
    my $gar;
    lives_ok sub {
        $gar = Socialtext::GroupAccountRole->new( {
            group_id   => 1,
            account_id => 2,
            role_id    => 3,
            bogus      => 'attribute',
        } );
    }, 'created GAR when additional attributes provided';
    isa_ok $gar, 'Socialtext::GroupAccountRole', '... created GAR';
}

###############################################################################
# TEST: instantiation with actual Group/Account/Role
instantiation_with_real_data: {
    my $group   = create_test_group();
    my $account = create_test_account();
    my $role    = Socialtext::Role->new(name => 'member');
    my $gar     = Socialtext::GroupAccountRole->new( {
        group_id   => $group->group_id,
        account_id => $account->account_id,
        role_id    => $role->role_id,
        } );
    isa_ok $gar, 'Socialtext::GroupAccountRole';

    is $gar->group_id,   $group->group_id,
        '... with the provided group_id';
    is $gar->account_id, $account->account_id,
        '... with the provided account_id';
    is $gar->role_id,    $role->role_id,
        '... with the provided role_id';

    is $gar->group->group_id,     $group->group_id,
        '... with the right inflated Group object';
    is $gar->account->account_id, $account->account_id,
        '... with the right inflated Account object';
    is $gar->role->role_id,       $role->role_id,
        '... with the right inflated Role object';
}

###############################################################################
# TEST: ST::(Group|Account|Role) are lazy-loaded
lazy_load_modules: {
    my $loaded = modules_loaded_by('Socialtext::GroupAccountRole');
    ok  $loaded->{'Socialtext::GroupAccountRole'}, 'ST::GAR loaded';
    ok !$loaded->{'Socialtext::Group'},    '... ST::Group lazy-loaded';
    ok !$loaded->{'Socialtext::Account'}, '... ST::Account lazy-loaded';
    ok !$loaded->{'Socialtext::Role'},    '... ST::Role lazy-loaded';
}
