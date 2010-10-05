#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use mocked 'Apache::Request';
use MIME::Base64;
use Socialtext::CredentialsExtractor;
use Socialtext::AppConfig;
use Test::Socialtext tests => 4;
use Test::Socialtext::User;

fixtures(qw( empty ));

###############################################################################
### TEST DATA
###############################################################################
my $valid_username = Test::Socialtext::User->test_username();
my $valid_password = Test::Socialtext::User->test_password();
my $valid_user_id  = Socialtext::User->new(username => $valid_username)->user_id;
my $guest_user_id  = Socialtext::User->Guest->user_id;

my $bad_username = 'unknown_user@socialtext.com';
my $bad_password = '*bad-password*';

my $creds_extractors = 'BasicAuth:Guest';

###############################################################################
# TEST: Username+password are correct, user can authenticate
correct_username_and_password: {
    # create a mocked Apache::Request to extract the credentials from
    my $mock_request = make_mocked_request($valid_username, $valid_password);

    # configure the list of Credentials Extractors to run
    Socialtext::AppConfig->set(credentials_extractors => $creds_extractors);

    # extract the credentials
    my $user_id
        = Socialtext::CredentialsExtractor->ExtractCredentials($mock_request);
    is $user_id, $valid_user_id,
        'extracted credentials when username+password are valid';
}

###############################################################################
# TEST: Incorrect password, user cannot authenticate
incorrect_password: {
    # create a mocked Apache::Request to extract the credentials from
    my $mock_request = make_mocked_request($valid_username, $bad_password);

    # configure the list of Credentials Extractors to run
    Socialtext::AppConfig->set(credentials_extractors => $creds_extractors);

    # extract the credentials
    my $username
        = Socialtext::CredentialsExtractor->ExtractCredentials($mock_request);
    is $username, $guest_user_id,
        'unable to extract credentials when password is incorrect';
}

###############################################################################
# TEST: Unknown username, user cannot authenticate
unknown_username: {
    # create a mocked Apache::Request to extract the credentials from
    my $mock_request = make_mocked_request($bad_username, $bad_password);

    # configure the list of Credentials Extractors to run
    Socialtext::AppConfig->set(credentials_extractors => $creds_extractors);

    # extract the credentials
    my $user_id
        = Socialtext::CredentialsExtractor->ExtractCredentials($mock_request);
    is $user_id, $guest_user_id,
        'unable to extract credentials when username is unknown';
}

###############################################################################
# TEST: No authentication header set, not authenticated
no_authentication_header_set: {
    # create a mocked Apache::Request to extract the credentials from
    my $mock_request = make_mocked_request();

    # configure the list of Credentials Extractors to run
    Socialtext::AppConfig->set(credentials_extractors => $creds_extractors);

    # extract the credentials
    my $user_id
        = Socialtext::CredentialsExtractor->ExtractCredentials($mock_request);
    is $user_id, $guest_user_id,
        'unable to extract credentials when no Authen info provided';
}



sub make_mocked_request {
    my ($username, $password) = @_;
    my %args = (
        uri => 'http://localhost/challenge',
    );

    if ($username && $password) {
        my $encoded = MIME::Base64::encode("$username\:$password");
        $args{'Authorization'} = "Basic $encoded";
    }

    return Apache::Request->new(%args);
}
