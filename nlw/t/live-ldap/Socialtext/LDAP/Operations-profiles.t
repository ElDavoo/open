#!/usr/bin/env perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Test::Socialtext tests => 10;
use Test::Socialtext::User;
use Socialtext::LDAP::Operations;

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
# Make *ALL* profile lookups synchronous (easier testing)
$Socialtext::Pluggable::Plugin::People::Asynchronous=0;

###############################################################################
sub bootstrap_openldap {
    my %p    = @_;
    my $acct = $p{account};

    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    $openldap->add_ldif('t/test-data/ldap/base_dn.ldif');
    $openldap->add_ldif('t/test-data/ldap/relationships.ldif');

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
# TEST: Load LDAP Users, and make sure their Profiles get loaded.
load_users_populates_profiles: {
    my $guard = Test::Socialtext::User->snapshot();
    my $acct  = Socialtext::Account->Default;
    my $ldap  = bootstrap_openldap(account => $acct);

    # Load LDAP Users
    Socialtext::LDAP::Operations->LoadUsers();

    # Get the Profile for a User, and make sure that it has a Manager.
    #
    # Have to cheat a bit here when fetching the profile, as we *don't* want
    # to trigger any behaviour that would cause ST::User->new() to be called
    # for the User in question (as _that_ could in turn load the User and
    # cloud our ability to see that it was LoadUsers() that did the work for
    # us).
    my $ariel_dn = 'cn=Ariel Young,ou=related,dc=example,dc=com';
    my $ariel_id = Socialtext::User->ResolveId(driver_unique_id => $ariel_dn);
    ok $ariel_id, 'Resolved UserId for Ariel';

    my $adrian_dn = 'cn=Adrian Harris,ou=related,dc=example,dc=com';
    my $adrian_id = Socialtext::User->ResolveId(driver_unique_id => $adrian_dn);
    ok $adrian_id, 'Resolved UserId for Adrian';

    my $profile = Socialtext::People::Profile->_fetch_profile($ariel_id);
    ok $profile, 'Ariel has a profile';
    is $profile->{supervisor}, $adrian_id, '... and Adrian is her Manager';
}

###############################################################################
# TEST: Refresh LDAP Users, and make sure their Profiles get updated.
refresh_users_also_updates_profiles: {
    my $guard = Test::Socialtext::User->snapshot();
    my $acct  = Socialtext::Account->Default;
    my $ldap  = bootstrap_openldap(account => $acct);

    # Load Users from LDAP into ST
    my $ariel = Socialtext::User->new(username => 'Ariel Young');
    ok $ariel, 'loaded Ariel user';
    my $adrian = Socialtext::User->new(username => 'Adrian Harris');
    ok $adrian, 'loaded Adrian user';
    my $belinda = Socialtext::User->new(username => 'Belinda King');
    ok $belinda, 'loaded Belinda user';

    # Update a User's Profile in LDAP
    my $ariel_dn   = 'cn=Ariel Young,ou=related,dc=example,dc=com';
    my $belinda_dn = 'cn=Belinda King,ou=related,dc=example,dc=com';

    my $ariel_profile = Socialtext::People::Profile->GetProfile($ariel, no_recurse=>1);
    is $ariel_profile->get_reln('supervisor'), $adrian->user_id,
        'Ariel starts with Adrian as her Manager';

    my $rc = $ldap->modify($ariel_dn, replace => ['manager' => $belinda_dn]);
    ok $rc, 'updated LDAP to now show Belinda as a Manager';

    # Refresh Users
    Socialtext::LDAP::Operations->RefreshUsers(force => 1);

    # Check that the Profile got updated properly
    $ariel_profile = Socialtext::People::Profile->GetProfile($ariel, no_recurse=>1);
    is $ariel_profile->get_reln('supervisor'), $belinda->user_id,
        'Ariel has Belinda as a manager after RefreshUsers';
}
