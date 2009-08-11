#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use mocked 'Socialtext::Events', qw(clear_events event_ok is_event_count);
use mocked 'Socialtext::Log', qw(:tests);
use Test::Socialtext::Bootstrap::OpenLDAP;
use Test::Socialtext tests => 65;

###############################################################################
# Fixtures: clean db
# - needs a DB
fixtures(qw( db ));

###############################################################################
sub bootstrap_openldap {
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    ok $openldap->add_ldif('t/test-data/ldap/base_dn.ldif'), 'added base_dn';
    ok $openldap->add_ldif('t/test-data/ldap/people.ldif'),  'added people';
    ok $openldap->add_ldif('t/test-data/ldap/groups-groupOfNames.ldif'), 'added groups';
    return $openldap;
}

###############################################################################
# TEST: instantiate an LDAP Group Factory
instantiate_ldap_group_factory: {
    my $openldap    = bootstrap_openldap();
    my $factory_key = $openldap->_as_factory();
    my $factory = Socialtext::Group->Factory(driver_key => $factory_key);
    isa_ok $factory, 'Socialtext::Group::LDAP::Factory';
}

###############################################################################
# TEST: retrieve an LDAP Group
retrieve_ldap_group: {
    my $openldap  = bootstrap_openldap();
    my $group_dn  = 'cn=Motorhead,dc=example,dc=com';
    my $motorhead = Socialtext::Group->GetGroup(
        driver_unique_id => $group_dn,
    );
    isa_ok $motorhead, 'Socialtext::Group';
    isa_ok $motorhead->homunculus, 'Socialtext::Group::LDAP';
    is $motorhead->driver_group_name, 'Motorhead';

    my $users = $motorhead->users;
    isa_ok $users => 'Socialtext::MultiCursor';
    is $users->count => '3', '... with correct number of users';

    my $user = $users->next();
    is $user->username => 'lemmy kilmister', '... first user has correct name';

    $user = $users->next();
    is $user->username => 'phil taylor', '... second user has correct name';

    $user = $users->next();
    is $user->username => 'eddie clarke', '... third user has correct name';

    # CLEANUP
    Test::Socialtext::Group->delete_recklessly($motorhead);
}

###############################################################################
# TEST: retrieve a *nested* LDAP Group
retrieve_nested_ldap_group: {
    my $openldap = bootstrap_openldap();
    my $group_dn = 'cn=Hawkwind,dc=example,dc=com';
    my $hawkwind = Socialtext::Group->GetGroup(
        driver_unique_id => $group_dn,
    );
    isa_ok $hawkwind, 'Socialtext::Group';
    isa_ok $hawkwind->homunculus, 'Socialtext::Group::LDAP';
    is $hawkwind->driver_group_name, 'Hawkwind';

    my $users = $hawkwind->users;
    isa_ok $users => 'Socialtext::MultiCursor';
    is $users->count => '4', '... with correct number of users';

    my $user = $users->next();
    is $user->username => 'michael moorcock', '... first user has correct name';

    $user = $users->next();
    is $user->username => 'lemmy kilmister', '... second user has correct name';

    $user = $users->next();
    is $user->username => 'phil taylor', '... third user has correct name';

    $user = $users->next();
    is $user->username => 'eddie clarke', '... fourth user has correct name';

    # CLEANUP
    Test::Socialtext::Group->delete_recklessly($hawkwind);
}

###############################################################################
# TEST: retrieve a nested LDAP Group that has circular Group references
retrieve_nested_ldap_group_circular_references: {
    my $openldap = bootstrap_openldap();
    my $group_dn = 'cn=Circular A,dc=example,dc=com';
    my $circular = Socialtext::Group->GetGroup(
        driver_unique_id => $group_dn,
    );
    isa_ok $circular, 'Socialtext::Group';
    isa_ok $circular->homunculus, 'Socialtext::Group::LDAP';
    is $circular->driver_group_name, 'Circular A';

    my $users = $circular->users;
    isa_ok $users => 'Socialtext::MultiCursor';
    is $users->count => '2', '... with correct number of users';

    my $user = $users->next();
    is $user->username => 'michael moorcock', '... first user has correct name';

    $user = $users->next();
    is $user->username => 'phil taylor', '... second user has correct name';

    # CLEANUP
    Test::Socialtext::Group->delete_recklessly($circular);
}

###############################################################################
# When a User is removed from the Group, membership list updated automatically
remove_user_from_group: {
    my $openldap = bootstrap_openldap();
    my $group_dn = 'cn=Motorhead,dc=example,dc=com';

    # get the Group, make sure it looks right
    my $motorhead = Socialtext::Group->GetGroup(
        driver_unique_id => $group_dn,
    );

    my $users = $motorhead->users;
    isa_ok $users => 'Socialtext::MultiCursor';
    is $users->count => '3', '... with three users';

    # expire the Group, so subsequent lookups will cause it to get refreshed
    $motorhead->expire();

    # update the Group in LDAP, removing one of its members
    my $rc = $openldap->modify(
        $group_dn,
        replace => [
            member => [
                "cn=Lemmy Kilmister,dc=example,dc=com",
                "cn=Eddie Clarke,dc=example,dc=com",
            ],
        ],
    );
    ok $rc, 'ldap store updated, user removed.';

    # re-instantiate the Group, and verify that the User was removed
    $motorhead = Socialtext::Group->GetGroup(
        driver_unique_id => $group_dn,
    );

    $users = $motorhead->users;
    isa_ok $users => 'Socialtext::MultiCursor';
    is $users->count => '2', '... with two users';

    my $user = $users->next();
    is $user->username => 'lemmy kilmister', '... first user has correct name';

    $user = $users->next();
    is $user->username => 'eddie clarke', '... third user has correct name';

    # CLEANUP
    Test::Socialtext::Group->delete_recklessly($motorhead);
}

###############################################################################
# Events get properly recorded when Users are added/removed
ldap_group_records_events_on_membership_change: {
    my $openldap = bootstrap_openldap();
    my $group_dn = 'cn=Motorhead,dc=example,dc=com';

    # Get the Group, make sure that the "create_role" Events were emitted
    clear_events();
    clear_log();
    my $motorhead = Socialtext::Group->GetGroup(
        driver_unique_id => $group_dn,
    );

    is_event_count 3;
    event_ok( event_class => 'group', action => 'create_role' );
    next_log_like 'info', qr/ASSIGN,GROUP_ROLE/, '... and shows in nlw.log';

    event_ok( event_class => 'group', action => 'create_role' );
    next_log_like 'info', qr/ASSIGN,GROUP_ROLE/, '... and shows in nlw.log';

    event_ok( event_class => 'group', action => 'create_role' );
    next_log_like 'info', qr/ASSIGN,GROUP_ROLE/, '... and shows in nlw.log';

    # expire the Group, so subsequent lookups will cause it to get refreshed
    $motorhead->expire();

    # update the Group in LDAP, removing one of its members
    my $rc = $openldap->modify(
        $group_dn,
        replace => [
            member => [
                "cn=Lemmy Kilmister,dc=example,dc=com",
                "cn=Eddie Clarke,dc=example,dc=com",
            ],
        ],
    );
    ok $rc, 'ldap store updated, user removed.';

    # Re-query the Group, and make sure that the "delete_role" Event was
    # emitted
    $motorhead = Socialtext::Group->GetGroup(
        driver_unique_id => $group_dn,
    );

    is_event_count 1;
    event_ok( event_class => 'group', action => 'delete_role' );
    next_log_like 'info', qr/REMOVE,GROUP_ROLE/, '... and shows in nlw.log';
}
