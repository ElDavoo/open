#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Test::Socialtext tests => 19;

# Explicitly load these, so we *know* they're loaded (instead of just waiting
# for them to be lazy loaded); we need to set some pkg vars for testing
use Socialtext::People::Profile;
use Socialtext::People::Fields;

# We're destructive, as we monkey around with the People Fields setup for the
# Default Account.  *Far* easier to just mark ourselves as destructive than it
# is to do this cleanly.
fixtures(qw( db destructive ));

###############################################################################
# Force People Profile Fields to be automatically created, so we don't have to
# set up the default sets of fields from scratch.
$Socialtext::People::Fields::AutomaticStockFields=1;

###############################################################################
sub bootstrap_openldap {
    my %p    = @_;
    my $acct = $p{account};

    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP';
    ok $openldap->add_ldif('t/test-data/ldap/base_dn.ldif'),
        '.. added data: base_dn';
    ok $openldap->add_ldif('t/test-data/ldap/relationships.ldif'),
        '... added data: relationships';

    # Update the "supervisor" People Field in this Account so its LDAP sourced
    my $people = Socialtext::Pluggable::Adapter->plugin_class('people');
    $people->SetProfileField( {
        name    => 'supervisor',
        source  => 'external',
        account => $acct,
    } );

    # Ensure that the LDAP config maps the "supervisor" field to an LDAP attr
    my $config = $openldap->ldap_config();
    $config->{attr_map}{supervisor} = 'manager';
    Socialtext::LDAP::Config->save($config);

    return $openldap;
}

###############################################################################
# TEST: instantiate User with a Supervisor
instantiate_user_with_supervisor: {
    my $acct = Socialtext::Account->Default;
    my $ldap = bootstrap_openldap(account => $acct);

    # Load up a User that has a Supervisor, and the Supervisor itself
    my $user = Socialtext::User->new(username => 'Ariel Young');
    ok $user, 'loaded User with a supervisor';

    my $supervisor = Socialtext::User->new(username => 'Adrian Harris');
    ok $supervisor, 'loaded Supervisor';

    # Check that the Supervisor was loaded _into_ the Default Account
    is $supervisor->primary_account_id, $acct->account_id,
        '... who was loaded into the Default Account';

    # Check that the Supervisor is linked in the Profile
    my $profile = Socialtext::People::Profile->GetProfile($user, no_recurse=>1);
    ok $profile, 'got People Profile';

    my $queried = $profile->get_reln('supervisor');
    ok $queried, '... that has a supervisor';
    is $queried, $supervisor->user_id, '... ... and its who we expect';
};

###############################################################################
# TEST: supervisor gets cleared in LDAP
supervisor_cleared: {
    my $acct = Socialtext::Account->Default;
    my $ldap = bootstrap_openldap(account => $acct);

    # Load up a User that has a Supervisor, and the Supervisor itself
    my $user = Socialtext::User->new(username => 'Ariel Young');
    ok $user, 'loaded User with a supervisor';

    my $supervisor = Socialtext::User->new(username => 'Adrian Harris');
    ok $supervisor, 'loaded Supervisor';

    # Check that the Supervisor is linked in the Profile
    my $profile = Socialtext::People::Profile->GetProfile($user, no_recurse=>1);
    ok $profile, 'got People Profile';

    my $queried = $profile->get_reln('supervisor');
    ok $queried, '... that has a supervisor';
    is $queried, $supervisor->user_id, '... ... and its who we expect';

    # Clear the Supervisor in LDAP, refresh, and make sure it got cleared.
    my $rc = $ldap->modify($user->driver_unique_id, delete => [qw(manager)]);
    ok $rc, 'modified User in LDAP, removing supervisor';

    $user->homunculus->expire();

    $user    = Socialtext::User->new(username => 'Ariel Young');
    $profile = Socialtext::People::Profile->GetProfile($user, no_recurse=>1);
    $queried = $profile->get_reln('supervisor');
    ok !defined $queried, '... removal of supervisor reflected in People Profile';
}
