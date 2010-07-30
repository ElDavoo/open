#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Test::Socialtext tests => 3;

fixtures(qw( db ));

###############################################################################
# TEST DATA
my $test_dn = 'cn=John Doe,dc=example,dc=com';

###############################################################################
# TEST: resolve system-user
resolve_system_user: {
    my $sys_user = Socialtext::User->SystemUser;
    my $expected = $sys_user->user_id;
    my $found    = Socialtext::User->ResolveId( {
        driver_unique_id => $sys_user->driver_unique_id,
    } );
    is $found, $expected, 'ResolveId for system-user';
}

###############################################################################
# TEST: resolve an LDAP User that doesn't exist in ST yet
resolve_unvivified_ldap_user: {
    my $ldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    $ldap->add_ldif('t/test-data/ldap/base_dn.ldif');
    $ldap->add_ldif('t/test-data/ldap/people.ldif');

    my $john_id = Socialtext::User->ResolveId( {
        driver_unique_id => $test_dn,
    } );
    ok !$john_id, 'ResolveId for un-vivified LDAP User; no user_id';
}

###############################################################################
# TEST: resolve an LDAP User that HAS been vivified into ST
resolve_ldap_user: {
    my $ldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    $ldap->add_ldif('t/test-data/ldap/base_dn.ldif');
    $ldap->add_ldif('t/test-data/ldap/people.ldif');

    my $john = Socialtext::User->new(driver_unique_id => $test_dn);

    my $expected = $john->user_id;
    my $found    = Socialtext::User->ResolveId( {
        driver_unique_id => $test_dn,
    } );
    is $found, $expected, 'ResolveId for vivified LDAP User';
}
