#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Test::Socialtext::User;
use Test::Socialtext tests => 21;

###############################################################################
# FIXTURE:  db
# - Need a DB, don't care what's in it.
fixtures(qw( db ));

###############################################################################
# TEST: User has been removed from LDAP server
ldap_user_removed: {
    # Bootstrap OpenLDAP
    my $guard    = Test::Socialtext::User->snapshot();
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    ok $openldap->add_ldif('t/test-data/ldap/base_dn.ldif'),
        '... added data: base_dn';
    ok $openldap->add_ldif('t/test-data/ldap/people.ldif'),
        '... added data: people';

    # Vivify an LDAP User
    my $user = Socialtext::User->new( username => 'John Doe' );
    isa_ok $user, 'Socialtext::User', 'LDAP User';
    isa_ok $user->homunculus(), 'Socialtext::User::LDAP', '... homunculus';
    my $user_dn = $user->homunculus->driver_unique_id;

    # Remove the User from LDAP, so they're now "deleted"
    ok $openldap->remove($user_dn), 'deleted User in LDAP';

    # Expire the cached copy of the User, and refresh it
    $user->homunculus->expire();
    my $refreshed = Socialtext::User->new( username => 'John Doe' );

    # Verify that it is a "Deleted User" object
    isa_ok $refreshed, 'Socialtext::User', 'Refreshed LDAP User';
    isa_ok $refreshed->homunculus, 'Socialtext::User::Deleted', '... deleted homunculus';

    # Verify that we have the last cached data from LDAP
    is $refreshed->username, $user->username,
        '... ... which has "last cached" username';
    is $refreshed->first_name, $user->first_name,
        '... ... which has "last cached" first_name';
    is $refreshed->last_name, $user->last_name,
        '... ... which has "last cached" last_name';
    is $refreshed->email_address, $user->email_address,
        '... ... which has "last cached" email_address';
}

###############################################################################
# TEST: LDAP server has been decommissioned
ldap_server_decommissioned: {
    # Bootstrap OpenLDAP
    my $guard    = Test::Socialtext::User->snapshot();
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    ok $openldap->add_ldif('t/test-data/ldap/base_dn.ldif'),
        '... added data: base_dn';
    ok $openldap->add_ldif('t/test-data/ldap/people.ldif'),
        '... added data: people';

    # Vivify an LDAP User
    my $user = Socialtext::User->new( username => 'Jane Smith' );
    isa_ok $user, 'Socialtext::User', 'LDAP User';
    isa_ok $user->homunculus(), 'Socialtext::User::LDAP', '... homunculus';
    my $user_dn = $user->homunculus->driver_unique_id;

    # Decommission the LDAP server
    undef $openldap;

    # Expire the cached copy of the User, and refresh it
    $user->homunculus->expire();
    my $refreshed = Socialtext::User->new( user_id => $user->user_id );

    # Verify that it is a "Deleted User" object
    isa_ok $refreshed, 'Socialtext::User', 'Refreshed LDAP User';
    isa_ok $refreshed->homunculus, 'Socialtext::User::Deleted', '... deleted homunculus';

    # Verify that we have the last cached data from LDAP
    is $refreshed->username, $user->username,
        '... ... which has "last cached" username';
    is $refreshed->first_name, $user->first_name,
        '... ... which has "last cached" first_name';
    is $refreshed->last_name, $user->last_name,
        '... ... which has "last cached" last_name';
    is $refreshed->email_address, $user->email_address,
        '... ... which has "last cached" email_address';
}
