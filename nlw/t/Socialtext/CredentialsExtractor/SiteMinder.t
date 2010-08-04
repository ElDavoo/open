#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use mocked 'Apache::Request';
use Socialtext::CredentialsExtractor;
use Socialtext::AppConfig;
use Test::Socialtext tests => 5;

fixtures(qw( base_config ));

###############################################################################
## TEST DATA
###############################################################################
my $valid_username   = Test::Socialtext::User->test_username();
my $bogus_username   = 'totally-bogus-unknown-user';
my $creds_extractors = 'SiteMinder:Guest';

Socialtext::AppConfig->set(credentials_extractors => $creds_extractors);

###############################################################################
# TEST: No SiteMinder credentials
no_credentials: {
    my $mock_request = Apache::Request->new();

    my $username = Socialtext::CredentialsExtractor->ExtractCredentials(
        $mock_request,
    );
    is $username, undef, 'No credentials provided, none found';
}

###############################################################################
# TEST: SiteMinder User, but no running session
siteminder_user_without_session: {
    my $mock_request = Apache::Request->new(
        SM_USER => $valid_username,
    );

    my $username = Socialtext::CredentialsExtractor->ExtractCredentials(
        $mock_request,
    );
    is $username, undef, 'User provided, but no running SiteMinder session';
}

###############################################################################
# TEST: SiteMinder User, with a valid session
siteminder_user_in_session: {
    my $mock_request = Apache::Request->new(
        SM_USER            => $valid_username,
        SM_SERVERSESSIONID => 'abc123',
    );

    my $username = Socialtext::CredentialsExtractor->ExtractCredentials(
        $mock_request,
    );
    is $username, $valid_username, 'User provided, with SiteMinder session';
}

siteminder_user_in_session_with_domain: {
    my $mock_request = Apache::Request->new(
        SM_USER            => "DOMAIN\\$valid_username",
        SM_SERVERSESSIONID => 'abc123',
    );

    my $username = Socialtext::CredentialsExtractor->ExtractCredentials(
        $mock_request,
    );
    is $username, $valid_username, 'User provided w/ domain, with SiteMinder session';
}

###############################################################################
# TEST: SiteMinder session, but *without* a User (e.g. username provided in
# a different HTTP header)
siteminder_session_without_user: {
    my $mock_request = Apache::Request->new(
        MISNAMED_SM_USER   => $valid_username,
        SM_SERVERSESSIONID => 'abc123',
    );

    my $username = Socialtext::CredentialsExtractor->ExtractCredentials(
        $mock_request,
    );
    is $username, undef, 'Session active, but unable to find username';
}
