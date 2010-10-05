#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use mocked 'Apache::Request';
use Socialtext::CredentialsExtractor;
use Socialtext::AppConfig;
use Test::Socialtext tests => 2;
use Test::Socialtext::User;

###############################################################################
# Fixtures: base_config
#
# Need to have the config files present/available, but don't need anything
# else.
fixtures(qw( base_config ));

###############################################################################
### TEST DATA
###############################################################################
my $valid_username = Test::Socialtext::User->test_username();
my $valid_user_id  = Socialtext::User->new(username => $valid_username)->user_id;
my $guest_user_id  = Socialtext::User->Guest->user_id;

my $creds_extractors = 'Apache:Guest';

###############################################################################
# TEST: Apache has authenticated User
apache_has_authenticated: {
    # create a mocked Apache::Request to extract the credentials from
    local $ENV{REMOTE_USER} = $valid_username,
    my $mock_request = Apache::Request->new();

    # configure the list of Credentials Extractors to run
    Socialtext::AppConfig->set(credentials_extractors => $creds_extractors);

    # extract the credentials
    my $user_id
        = Socialtext::CredentialsExtractor->ExtractCredentials($mock_request);
    is $user_id, $valid_user_id, 'extracted credentials from Apache';
}

###############################################################################
# TEST: Apache has not authenticated User
apache_has_not_authenticated: {
    # create a mocked Apache::Request to extract the credentials from
    delete local $ENV{REMOTE_USER};
    my $mock_request = Apache::Request->new();

    # configure the list of Credentials Extractors to run
    Socialtext::AppConfig->set(credentials_extractors => $creds_extractors);

    # extract the credentials
    my $user_id
        = Socialtext::CredentialsExtractor->ExtractCredentials($mock_request);
    is $user_id, $guest_user_id,
        'unable to extract credentials; Apache did not authentticate';
}
