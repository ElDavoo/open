#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Test::Socialtext;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Socialtext::User;
use Socialtext::User::LDAP::Factory;
use Socialtext::AppConfig;
use Net::LDAP::Entry;
use Socialtext::SQL qw/sql_singlevalue/;
use File::Temp qw(tempdir);

fixtures('db');

$Socialtext::LDAP::CacheEnabled = 0;
$Socialtext::User::Cache::Enabled = 0;
$Socialtext::User::LDAP::Factory::CacheEnabled = 0;

my ($foo,$bar); # LDAP stores.
my $user; # test user

setup: {
    $foo = initialize_ldap('foo');
    $foo->add(
        'cn=Warren Maxwell,dc=foo,dc=com',
        objectClass => 'inetOrgPerson',
        cn => 'Warren Maxwell',
        gn => 'Warren',
        sn => 'Maxwell',
        mail => 'warren@example.com',
        userPassword => 'password',
    );

    $bar = initialize_ldap('bar');
    $bar->add(
        'cn=Warren Maxwell,dc=bar,dc=com',
        objectClass => 'inetOrgPerson',
        cn => 'Warren Maxwell',
        gn => 'Warren',
        sn => 'Maxwell',
        mail => 'warren@example.com',
        userPassword => 'password',
    );
}

set_user_factories('Default');
create_user_in_default: {
    $user = Socialtext::User->new(username=>'warren');
    is $user, undef, 'user does not exist in socialtext';

    $user = Socialtext::User->create(
        email_address => 'warren@example.com',
        username => 'warren maxwell',
        password => 'password',
    );
    isa_ok $user, 'Socialtext::User', 'created a user';
    is $user->homunculus->driver_key, 'Default', 'user in default';
    user_is_unique_to_socialtext('warren maxwell');
}

set_user_factories($bar->as_factory, 'Default');
migrate_user_to_ldap: {
    $user = Socialtext::User->new(username=>'warren maxwell');
    isa_ok $user, 'Socialtext::User', 'found a user';
    is $user->homunculus->driver_key, $bar->as_factory, 'user in bar';
    user_is_unique_to_socialtext('warren maxwell');
}

set_user_factories($foo->as_factory, $bar->as_factory, 'Default');
user_switches_ldap: {
    $user = Socialtext::User->new(username=>'warren maxwell');
    isa_ok $user, 'Socialtext::User', 'found a user';
    is $user->homunculus->driver_key, $foo->as_factory, 'user in bar';
    user_is_unique_to_socialtext('warren maxwell');
}

$foo->remove('cn=Warren Maxwell,dc=foo,dc=com');
removed_user_migrates: {
    $user = Socialtext::User->new(username=>'warren maxwell');
    isa_ok $user, 'Socialtext::User', 'found a user';
    is $user->homunculus->driver_key, $bar->as_factory, 'user in bar';
    user_is_unique_to_socialtext('warren maxwell');
}

$bar->remove('cn=Warren Maxwell,dc=bar,dc=com');
cannot_find_user_in_ldap: {
    $user = Socialtext::User->new(username=>'warren maxwell');
    isa_ok $user, 'Socialtext::User', 'found a user';
    is $user->missing, 1, 'user is flagged as missing';
    user_is_unique_to_socialtext('warren maxwell');
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

sub user_is_unique_to_socialtext {
    my $username = shift;
    my $driver_key = shift;

    my $count = sql_singlevalue(qq{
        SELECT COUNT(*) 
          FROM users
         WHERE driver_username = ?
    }, $username);
    is $count, 1, "one copy of $username exists";
}

sub set_user_factories {
    my $new_factories = join(';', @_);

    Socialtext::AppConfig->set(user_factories => $new_factories);
    Socialtext::AppConfig->write();

    my $factories = Socialtext::AppConfig->user_factories();
    is $factories, $new_factories, "factories are $new_factories";

    return $factories;
}
