#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext qw/no_plan/;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Socialtext::User;
use Socialtext::Role;

fixtures( 'db', 'destructive' );

###############################################################################
sub bootstrap_openldap {
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP';
    ok $openldap->add_ldif('t/test-data/ldap/base_dn.ldif'),
        '.. added data: base_dn';
    ok $openldap->add_ldif('t/test-data/ldap/people.ldif'),
        '... added data: people';
    ok $openldap->add_ldif('t/test-data/ldap/groups-groupOfNames.ldif'),
        '... added data: groups';
    return $openldap;
}

###############################################################################
user_vivified_into_all_users_workspace: {
    my $openldap = bootstrap_openldap();
    my $account  = Socialtext::Account->Default();
    my $ws       = create_test_workspace();
    my $member   = Socialtext::Role->Member();

    # Setup
    $account->update( all_users_workspace => $ws->workspace_id );
    is $account->all_users_workspace, $ws->workspace_id,
        'set all users Workspace';

    # Vivify an LDAP User
    my $user = Socialtext::User->new(
        email_address => 'ray.parker@example.com');
    isa_ok $user, 'Socialtext::User', 'got an LDAP User';

    # Verify that the user is in the account and the all Users Workspace.
    is $user->primary_account_id, $account->account_id,
        'User has default account as primary Account';

    my $role = $ws->role_for_user( user => $user );
    ok $role, 'User has Role in all users Workspace';
    is $role->role_id, $member->role_id, '... Role is Member';

    # Teardown
    $account->update( all_users_workspace => undef );
    is $account->all_users_workspace, undef,
        'unset all users Workspace';
}
