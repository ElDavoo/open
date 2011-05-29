#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Socialtext;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Socialtext::User;
use Socialtext::User::LDAP::Factory;
use Socialtext::AppConfig;
use Socialtext::LDAP::Operations;
use Net::LDAP::Entry;
use Socialtext::SQL qw/sql_singlevalue/;
use File::Temp qw(tempdir);

fixtures('db');

$Socialtext::LDAP::CacheEnabled = 0;
$Socialtext::User::Cache::Enabled = 0;
$Socialtext::User::LDAP::Factory::CacheEnabled = 0;

my ($one,$two); # LDAP stores.
my $one_dn = 'cn=Warren Maxwell,ou=people,dc=foo,dc=com';
my $two_dn = 'cn=Warren Maxwell,ou=terminated,dc=foo,dc=com';
my $user; # test user

setup: { # same user 2x, but with different dn's in different LDAPs.
    $one = initialize_ldap('foo');
    $one->add(
        'ou=people,dc=foo,dc=com',
        objectClass => 'organizationalUnit',
        description => ' current employees',
        ou => 'people',
    );
    $one->add(
        $one_dn,
        objectClass => 'inetOrgPerson',
        cn => 'Warren Maxwell',
        ou => 'people',
        gn => 'Warren',
        sn => 'Maxwell',
        mail => 'warren@example.com',
        userPassword => 'password',
    );

    $two = initialize_ldap('foo');
    $two->add(
        'ou=terminated,dc=foo,dc=com',
        objectClass => 'organizationalUnit',
        description => ' current employees',
        ou => 'terminated',
    );
    $two->add(
        $two_dn,
        objectClass => 'inetOrgPerson',
        cn => 'Warren Maxwell',
        ou => 'terminated',
        gn => 'Warren',
        sn => 'Maxwell',
        mail => 'warren@example.com',
        userPassword => 'password',
    );
}

set_user_factories($one->as_factory, $two->as_factory);
vivify_user: {
    $user = Socialtext::User->new(username=>'warren maxwell');
    isa_ok $user, 'Socialtext::User', 'vivified user';
    is $user->homunculus->driver_key, $one->as_factory, 'user has factory';
    is $user->driver_unique_id, $one_dn, 'user has dn';
}

simple_refresh: {
    Socialtext::LDAP::Operations->RefreshUsers();
    $user = Socialtext::User->new(username=>'warren maxwell');
    isa_ok $user, 'Socialtext::User', 'freshened user';
    is $user->homunculus->driver_key, $one->as_factory, 'user has factory';
    is $user->driver_unique_id, $one_dn, 'user has dn';
}

set_user_factories($two->as_factory, $one->as_factory);
refresh_with_updated_ldap: {
    Socialtext::LDAP::Operations->RefreshUsers();
    $user = Socialtext::User->new(username=>'warren maxwell');
    isa_ok $user, 'Socialtext::User', 'freshened user with new ldap';
    is $user->homunculus->driver_key, $one->as_factory, 'user has factory';
    is $user->driver_unique_id, $one_dn, 'user has dn';
}

done_testing;
################################################################################

sub initialize_ldap {
    my $dc = shift;
    my $dir = shift || tempdir(TMPDIR=>1, CLEANUP=>1); 

    my $dn = "dc=${dc},dc=com";
    my $ldap = Test::Socialtext::Bootstrap::OpenLDAP->new(base_dn=>$dn);

    my $entry = Net::LDAP::Entry->new();
    $entry->changetype('add');
    $entry->dn($dn);
    $entry->add(
        objectClass => 'dcObject',
        objectClass => 'organization',
        dc => $dc,
        o => "$dc dot com",
    );
    my $rc = $ldap->_update(
        \&Socialtext::Bootstrap::OpenLDAP::_cb_add_entry, [$entry]);
    ok $rc, "added ldap store '$dc' with base object";

    return $ldap;
}

sub set_user_factories {
    my $new_factories = join(';', @_);

    Socialtext::AppConfig->set(user_factories => $new_factories);
    Socialtext::AppConfig->write();

    my $factories = Socialtext::AppConfig->user_factories();
    is $factories, $new_factories, "factories are $new_factories";

    return $factories;
}
