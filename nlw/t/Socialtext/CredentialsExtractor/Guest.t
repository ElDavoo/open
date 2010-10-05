#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use mocked 'Apache::Request';
use Socialtext::CredentialsExtractor;
use Socialtext::AppConfig;
use Socialtext::User;
use Test::Socialtext tests => 1;

###############################################################################
# Fixtures: base_config
#
# Need to have the config files present/available, but don't need anything
# else.
fixtures(qw( base_config ));

###############################################################################
### TEST DATA
###############################################################################
my $creds_extractors = 'Guest';
my $guest_user_id    = Socialtext::User->Guest->user_id;

###############################################################################
# TEST: Always fails to authenticate
guest_is_always_failure: {
    # create a mocked Apache::Request to extract the credentials from
    my $mock_request = Apache::Request->new();

    # configure the list of Credentials Extractors to run
    Socialtext::AppConfig->set(credentials_extractors => $creds_extractors);

    # extract the credentials
    my $user_id
        = Socialtext::CredentialsExtractor->ExtractCredentials($mock_request);
    is $user_id, $guest_user_id, 'Guest credentials extracted';
}
