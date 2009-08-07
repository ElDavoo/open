#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Test::Socialtext tests => 10;

###############################################################################
# Fixtures: clean db
# - XXX: needs a clean DB to start (Groups don't auto-cleanup yet)
# - needs a DB
# - XXX: we're destructive (we add Groups to DB, which don't auto-cleanup yet)
fixtures(qw( clean db destructive ));

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
}
