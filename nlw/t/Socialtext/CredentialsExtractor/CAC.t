#!/usr/bin/env perl

use strict;
use warnings;
use Socialtext::CredentialsExtractor;
use Socialtext::CredentialsExtractor::Extractor::CAC;
use Socialtext::AppConfig;
use Test::Socialtext tests => 13;

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
