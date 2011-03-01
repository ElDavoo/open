#!/usr/bin/env perl

use strict;
use warnings;
use Socialtext::CredentialsExtractor;
use Socialtext::CredentialsExtractor::Extractor::CAC;
use Socialtext::AppConfig;
use Test::Socialtext tests => 20;

fixtures(qw( empty ));

###############################################################################
# SETUP: create a Test User and assign them an EDIPIN.
my $edipin        = Test::Socialtext->create_unique_id();
my $test_user     = create_test_user(private_external_id => $edipin);
my $test_username = $test_user->username;
my $test_user_id  = $test_user->user_id;

Socialtext::AppConfig->set(credentials_extractors => 'CAC:Guest');

###############################################################################
# TEST: Parse username into fields
parse_username_into_fields: {
    # Parse successfully.
    my $username = 'first.middle.last.edipin';
    my %expected = (
        first_name  => 'first',
        middle_name => 'middle',
        last_name   => 'last',
        edipin      => 'edipin',
    );
    my %fields = Socialtext::CredentialsExtractor::Extractor::CAC
        ->_parse_cac_username($username);
    is_deeply \%fields, \%expected, 'Parsed username fields successfully';

    # Parse w/o edipin
    $username = 'first.middle.last';
    %expected =  ( );
    %fields = Socialtext::CredentialsExtractor::Extractor::CAC
        ->_parse_cac_username($username);
    is_deeply \%fields, \%expected, 'Cannot parse username when missing EDIPIN';

    # Parse when malformed (regular LDAP formatted name)
    $username = 'Bubba Bo Bob Brain';
    %expected =  ( );
    %fields = Socialtext::CredentialsExtractor::Extractor::CAC
        ->_parse_cac_username($username);
    is_deeply \%fields, \%expected, 'Cannot parse username when malformed';
}

###############################################################################
# TEST: Find partially provisioned Users.
find_partially_provisioned_users: {
    my %fields = (
        first_name  => 'David',
        middle_name => 'Michael',
        last_name   => 'Smith',
    );

    # Two matching UN-provisioned Users, non-matching UN-provisioned User, and
    # a provisioned User.
    my $user_one = create_test_user(%fields);
    Socialtext::User::Restrictions::require_external_id->CreateOrReplace(
        user_id => $user_one->user_id,
    );

    my $user_two = create_test_user(%fields);
    Socialtext::User::Restrictions::require_external_id->CreateOrReplace(
        user_id => $user_two->user_id,
    );

    my $diff_name_user = create_test_user(%fields, middle_name => 'Matt');
    Socialtext::User::Restrictions::require_external_id->CreateOrReplace(
        user_id => $diff_name_user->user_id,
    );

    my $provisioned_user = create_test_user(%fields);

    # Which Users did we find?
    my @users = Socialtext::CredentialsExtractor::Extractor::CAC
        ->_find_partially_provisioned_users(
            first_name  => 'David',
            middle_name => 'Michael',
            last_name   => 'Smith',
        );
    my @found    = map { $_->username } @users;
    my @expected = map { $_->username } ($user_one, $user_two);
    is_deeply \@found, \@expected, 'Found partially provisioned Users';
}

###############################################################################
# TEST: No CAC credentials
no_credentials: {
    my $guest_user_id = Socialtext::User->Guest->user_id;
    my $creds = Socialtext::CredentialsExtractor->ExtractCredentials( { } );
    ok $creds->{valid}, 'extracted credentials, no SSL Cert';
    is $creds->{user_id}, $guest_user_id, '... the Guest; fall-through';
}

###############################################################################
# TEST: Invalid format of SSL Certificiate subject (missing CN field)
invalid_subject_missing_field: {
    my $subject = "C=US, ST=CA, O=Socialtext, MAIL=$test_username";
    my $creds = Socialtext::CredentialsExtractor->ExtractCredentials( {
        X_SSL_CLIENT_SUBJECT => $subject,
    } );
    ok !$creds->{valid}, 'failed to extract creds when missing CN field';
    like $creds->{reason}, qr/invalid certificate subject/, '... invalid cert';
}

###############################################################################
# TEST: Invalid format of SSL Certificiate subject (malformed CN; no EDIPIN)
invalid_subject_malformed_cn: {
    my $subject = 'C=US, ST=CA, O=Socialtext, CN=Bubba Bo Bob Brain';
    my $creds = Socialtext::CredentialsExtractor->ExtractCredentials( {
        X_SSL_CLIENT_SUBJECT => $subject,
    } );
    ok !$creds->{valid}, 'failed to extract creds when CN is malformed';
    like $creds->{reason}, qr/invalid username/, '... invalid Username';
}

###############################################################################
# TEST: Valid cert, but the User doesn't exist
unknown_username: {
    my $subject = 'C=US, ST=CA, O=Socialtext, CN=first.middle.last.987654321';
    my $creds = Socialtext::CredentialsExtractor->ExtractCredentials( {
        X_SSL_CLIENT_SUBJECT => $subject,
    } );
    ok !$creds->{valid}, 'failed to extract creds when User is unknown';
    like $creds->{reason}, qr/invalid username/, '... unknown Username';
}

###############################################################################
# TEST: Valid cert, User exists
valid: {
    my $subject = "C=US, ST=CA, O=Socialtext, CN=first.middle.last.$edipin";
    my $creds = Socialtext::CredentialsExtractor->ExtractCredentials( {
        X_SSL_CLIENT_SUBJECT => $subject,
    } );
    ok $creds->{valid}, 'extracted creds from slash delimited subject';
    is $creds->{user_id}, $test_user_id, '... with valid User';
}

###############################################################################
# TEST: Auto-provision User, single User matches
auto_provision_user: {
    my $first  = 'Ian';
    my $middle = 'Lancaster';
    my $last   = 'Fleming';
    my $edipin = '123456789';

    # Create a User, flag them as being partially provisioned.
    my $user = create_test_user(
        first_name  => $first,
        middle_name => $middle,
        last_name   => $last,
    );
    ok $user, 'Created test User';

    Socialtext::User::Restrictions::require_external_id->CreateOrReplace(
        user_id => $user->user_id,
    );
    ok $user->requires_external_id, '... missing their external id';

    # Extract creds for this User
    my $subject = "C=UK, O=Goldeneye, CN=$first\.$middle\.$last\.$edipin";
    my $creds   = Socialtext::CredentialsExtractor->ExtractCredentials( {
        X_SSL_CLIENT_SUBJECT => $subject,
    } );
    ok $creds->{valid}, 'extracted creds for partially provisioned User';
    is $creds->{user_id}, $user->user_id, '... with correct User';

    $user->reload;
    ok !$user->requires_external_id, '... external id no longer required';
    is $user->private_external_id, $edipin, '... and with assigned EDIPIN';
}

# TEST: Auto-provision User, multiple User matches
# TEST: Auto-provision User, *no* matches
