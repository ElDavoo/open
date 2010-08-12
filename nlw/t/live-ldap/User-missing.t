#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use mocked 'Socialtext::Log', qw(:tests);
use Test::Socialtext::Bootstrap::OpenLDAP;
use Test::Socialtext tests => 17;

fixtures(qw( db ));

###############################################################################
sub bootstrap_openldap {
    my $ldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    $ldap->add_ldif('t/test-data/ldap/base_dn.ldif');
    $ldap->add_ldif('t/test-data/ldap/people.ldif');
    return $ldap;
}

###############################################################################
# Helper method to pull up the Homunculus straight from the DB; when we want
# to check if the DB got updated, we can't just check the User object (as
# instantiating the User object may give us a ST::User::Deleted, which
# explicitly sets/over-rides several attributes).
sub get_homunculus_for_dn {
    my $dn = shift;
    return Socialtext::User->_first('get_homunculus', driver_unique_id=>$dn);
}

###############################################################################
# TEST: Users found in LDAP are _not_ considered to be "missing".
existing_user_not_missing: {
    my $ldap = bootstrap_openldap();
    my $user = Socialtext::User->new(username => 'John Doe');
    isa_ok $user, 'Socialtext::User', 'existing User';
    ok !$user->missing, '... who is marked as _not_ missing';
}

###############################################################################
# TEST: User deemed "missing" when not in LDAP.
missing_when_not_in_ldap: {
    my $ldap = bootstrap_openldap();
    my $user = Socialtext::User->new(username => 'John Doe');
    isa_ok $user, 'Socialtext::User', 'existing User';

    # Grab the User directly from LDAP (so we can re-add him again later)
    my $conn = Socialtext::LDAP->new();
    my $dn   = $user->driver_unique_id;
    my $mesg = $conn->{ldap}->search(
        base   => $dn,
        filter => '(objectClass=inetOrgPerson)',
        attrs  => ['*'],
    );
    my ($entry) = $mesg->entries;
    ok $entry, '... found User entry in LDAP';

    # remove User from LDAP; should be "missing"
    remove_user: {
        my $mesg = $conn->{ldap}->delete($dn);
        ok !$mesg->is_error, '... removed User from LDAP';

        my $homey_before = get_homunculus_for_dn($dn);
        clear_log();

        $user->homunculus->expire;
        $user = Socialtext::User->new(username => 'John Doe');
        ok $user, '... ... requeried the User';
        ok $user->missing, '... ... and has been flagged as "missing"';
        logged_like 'info', qr/$dn.*missing/, '... ... logged to nlw.log';

        my $homey_after = get_homunculus_for_dn($dn);
        ok $homey_after->cached_at > $homey_before->cached_at,
            '... ... "cached_at" was updated';
    }

    # add User back into LDAP; should be "found" again
    restore_user: {
        my $mesg = $conn->{ldap}->add($entry);
        ok !$mesg->is_error, '... added User back into LDAP';

        my $homey_before = get_homunculus_for_dn($dn);
        clear_log();

        $user->homunculus->expire;
        $user = Socialtext::User->new(username => 'John Doe');
        ok $user, '... ... requeried the User';
        ok !$user->missing, '... ... and has been flagged as "found"';
        logged_like 'info', qr/$dn.*found/, '... ... logged to nlw.log';

        my $homey_after = get_homunculus_for_dn($dn);
        ok $homey_after->cached_at > $homey_before->cached_at,
            '... ... "cached_at" was updated';
    }
}

###############################################################################
# TEST: Missing Users always return "$user->is_deleted()" true
missing_users_are_deemed_deleted: {
    my $ldap = bootstrap_openldap();
    my $user = Socialtext::User->new(username => 'John Doe');
    my $conn = Socialtext::LDAP->new();
    my $dn   = $user->driver_unique_id;

    my $mesg = $conn->{ldap}->delete($dn);
    ok !$mesg->is_error, 'removed User from LDAP';

    $user->homunculus->expire;
    $user = Socialtext::User->new(username => 'John Doe');
    ok $user->missing, '... marked as "missing"';
    ok $user->is_deleted, '... and deemed is_deleted';
}
