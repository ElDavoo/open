#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use mocked 'Apache::Request';
use Socialtext::CredentialsExtractor;
use Socialtext::AppConfig;
use Test::Socialtext tests => 5;

###############################################################################
# Fixtures: empty
#
# Need to have the test User around.
fixtures(qw( empty ));

###############################################################################
## TEST DATA
###############################################################################
my $valid_username   = Test::Socialtext::User->test_username();
my $valid_user_id    = Socialtext::User->new(username => $valid_username)->user_id;
my $guest_user_id    = Socialtext::User->Guest->user_id;
my $bogus_username   = 'totally-bogus-unknown-user';
my $creds_extractors = 'SiteMinder:Guest';

Socialtext::AppConfig->set(credentials_extractors => $creds_extractors);

###############################################################################
# TEST: No SiteMinder credentials
no_credentials: {
    my $mock_request = Apache::Request->new();

    my $user_id = Socialtext::CredentialsExtractor->ExtractCredentials(
        $mock_request,
    );
    is $user_id, $guest_user_id, 'No credentials provided, none found';
}

###############################################################################
# TEST: SiteMinder User, but no running session
siteminder_user_without_session: {
    my $mock_request = Apache::Request->new(
        SM_USER => $valid_username,
    );

    my $user_id = Socialtext::CredentialsExtractor->ExtractCredentials(
        $mock_request,
    );
    is $user_id, $guest_user_id,
        'User provided, but no running SiteMinder session';
}

###############################################################################
# TEST: SiteMinder User, with a valid session
siteminder_user_in_session: {
    my $mock_request = Apache::Request->new(
        SM_USER            => $valid_username,
        SM_SERVERSESSIONID => 'abc123',
    );

    my $user_id = Socialtext::CredentialsExtractor->ExtractCredentials(
        $mock_request,
    );
    is $user_id, $valid_user_id, 'User provided, with SiteMinder session';
}

siteminder_user_in_session_with_domain: {
    my $mock_request = Apache::Request->new(
        SM_USER            => "DOMAIN\\$valid_username",
        SM_SERVERSESSIONID => 'abc123',
    );

    my $user_id = Socialtext::CredentialsExtractor->ExtractCredentials(
        $mock_request,
    );
    is $user_id, $valid_user_id, 'User provided w/ domain, with SiteMinder session';
}

###############################################################################
# TEST: SiteMinder session, but *without* a User (e.g. username provided in
# a different HTTP header)
siteminder_session_without_user: {
    my $mock_request = Apache::Request->new(
        MISNAMED_SM_USER   => $valid_username,
        SM_SERVERSESSIONID => 'abc123',
    );

    my $user_id = Socialtext::CredentialsExtractor->ExtractCredentials(
        $mock_request,
    );
    is $user_id, $guest_user_id, 'Session active, but unable to find username';
}
