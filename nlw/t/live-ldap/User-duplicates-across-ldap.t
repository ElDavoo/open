#!/usr/bin/env perl
use strict;
use warnings;

use Test::Socialtext tests => 23; 
use Test::Socialtext::Bootstrap::OpenLDAP;
use Socialtext::LDAP::Config;
use Socialtext::User;
use Socialtext::User::LDAP::Factory;
use Socialtext::AppConfig;
use Net::LDAP::Entry;
use Socialtext::SQL qw/sql_singlevalue sql_execute/;
use Guard;

fixtures('db');

$Socialtext::LDAP::CacheEnabled = 0;
$Socialtext::User::Cache::Enabled = 0;
$Socialtext::User::LDAP::Factory::CacheEnabled = 0;

my $LDAP;
my $TEST_ID = 'brandon noard';

create_openldap(); # create the initial store, it's empty.
my $primary_guard = scope_guard { teardown_openldap() };

no_user: {
    diag "no_user";
    my $user = Socialtext::User->new(username => $TEST_ID);
    is $user, undef, 'cannot find user, store is empty';
}

# add a Default user.
user_in_default_store: {
    diag "default_user";

    Socialtext::User->create(
        email_address => 'brandon.noard@socialtext.com',
        username => $TEST_ID,
        password => 'password',
    );

    my $user = Socialtext::User->new(username => $TEST_ID);
    isa_ok $user, 'Socialtext::User', 'got a user';
    is $user->homunculus->driver_key, 'Default', 'user in default';
    user_is_unique_to_socialtext('Default');
}

# add our internal LDAP to the list of stores. This store becomes a
# 'secondary' store.
add_secondary_store();
my $secondary_guard = scope_guard { remove_secondary_store() };

user_exists_in_secondary: {
    diag "user_exists_in_secondary";
    my $user = Socialtext::User->new(username => $TEST_ID);
    isa_ok $user, 'Socialtext::User', 'got a user';
    is $user->homunculus->driver_id, 'ST-ldap', 'user in secondary';
    user_is_unique_to_socialtext('LDAP:ST-ldap');
}

# add user to our initial store. This is the 'primary' store, so we'll find
# the email address here before our internal LDAP.
add_user_to_primary();

user_exists_in_primary: {
    diag "user_exists_in_primary";
    my $user = Socialtext::User->new(username => $TEST_ID);
    isa_ok $user, 'Socialtext::User', 'got a user';
    is $user->homunculus->driver_id, $LDAP->ldap_config->id,
        'user in primary';
    user_is_unique_to_socialtext('LDAP:'. $LDAP->ldap_config->id);
}

# user is removed from the primary store, but still exists in secondary.
remove_user_from_primary();

user_reverts_to_secondary: {
    diag "user_reverts_to_secondary";
    my $user = Socialtext::User->new(username => $TEST_ID);
    isa_ok $user, 'Socialtext::User', 'got a user';
    is $user->homunculus->driver_id, 'ST-ldap', 'user in secondary';
    user_is_unique_to_socialtext('LDAP:ST-ldap');
}

exit;

sub user_is_unique_to_socialtext {
    my $driver_key = shift;

    my $sth = sql_execute(qq{
        SELECT driver_key
          FROM users
         WHERE driver_username = ?
    }, $TEST_ID);
    my $rows = $sth->fetchall_arrayref();
use Data::Dumper; warn Dumper $rows;
    is scalar(@$rows), 1, 'found one copy of the user';
    is $rows->[0][0], $driver_key, 'found user has correct driver';
}

sub create_openldap {
    $LDAP = Test::Socialtext::Bootstrap::OpenLDAP->new(
        base_dn => 'dc=socialtext,dc=net',
    );

    # base object needs to be socialtext.net
    my $entry = Net::LDAP::Entry->new();
    $entry->changetype('add');
    $entry->dn('dc=socialtext,dc=net');
    $entry->add(
        objectClass => 'dcObject',
        objectClass => 'organization',
        dc => 'socialtext',
        o => 'socialtext dot net',
    );

    $LDAP->_update(
        \&Socialtext::Bootstrap::OpenLDAP::_cb_add_entry, [$entry]);

    return;
}

sub teardown_openldap {
    $LDAP->stop;
    $LDAP->teardown;
    undef $LDAP;

    diag "removed primary store";
}

sub update_factories {
    my $new_factories = shift;

    Socialtext::AppConfig->set(user_factories => $new_factories);
    Socialtext::AppConfig->write();

    my $factories = Socialtext::AppConfig->user_factories();
    is $factories, $new_factories, "factories are $new_factories";

    return $factories;
}

sub add_user_to_primary {
    my $rc = $LDAP->add(
        'cn=Brandon Noard,dc=socialtext,dc=net',
        objectClass => 'inetOrgPerson',
        cn => 'Brandon Noard',
        gn => 'Brandon',
        sn => 'Noard',
        mail => 'brandon.noard@socialtext.com',
        userPassword => 'password',
    );
    ok $rc, 'added user to primary LDAP';

    return;
}

sub remove_user_from_primary {
    my $rc = $LDAP->remove('cn=Brandon Noard,dc=socialtext,dc=net');
    ok $rc, 'removed user from primary LDAP';

    return;
}

sub add_secondary_store {
    my $ldap_id = $LDAP->ldap_config->id;

    add_config({
        id => 'ST-ldap',
        host => [qw/ldap1.socialtext.net ldap2.socialtext.net/],
        port => '389',
        base => 'dc=socialtext,dc=net',
        filter => '(objectClass=inetOrgPerson)',
        ttl => '3600',
        attr_map => {
          user_id => 'distinguishedName',
          username => 'cn',
          email_address => 'mail',
          first_name => 'givenName',
          last_name => 'sn',
        }
    });
    update_factories("LDAP:$ldap_id;LDAP:ST-ldap;Default");

    return;
}

sub remove_secondary_store {
    my $ldap_id = $LDAP->ldap_config->id;

    remove_config({id => 'ST-ldap'}, 1);
    update_factories("LDAP:$ldap_id;Default");

    diag "removed secondary store";
}

sub remove_config {
    add_config(shift, 1);
}

sub add_config {
    my $config = shift;
    my $remove = shift;

    my @loaded = grep { $_->{id} ne $config->{id} }
        Socialtext::LDAP::Config->load();
    my $count = scalar(@loaded);

    unless ($remove) {
        push @loaded, $config;
        $count++;
    }

    Socialtext::LDAP::Config->save(@loaded);

    my @freshened = Socialtext::LDAP::Config->load();
    is scalar(@freshened), $count, "config looks correct at $count";

    return \@loaded;
}
