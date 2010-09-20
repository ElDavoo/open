#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Digest::SHA;
use Socialtext::HTTP::Cookie qw(USER_DATA_COOKIE AIR_USER_COOKIE);
use Socialtext::AppConfig;
use Socialtext::CredentialsExtractor;
use Test::Socialtext tests => 5;
use Test::Socialtext::User;

###############################################################################
# Fixtures: empty
#
# Need to have the test User around.
fixtures(qw( empty ));

###############################################################################
### TEST DATA
###############################################################################
my $valid_username  = Test::Socialtext::User->test_username();
my $valid_user_id   = Socialtext::User->new(username => $valid_username)->user_id;
my $cookie_name     = USER_DATA_COOKIE();
my $air_cookie_name = AIR_USER_COOKIE();
my $air_user_agent  = 'Mozilla/5.0 (Windows; U; en) AppleWebKit/420+ (KHTML, like Gecko) AdobeAIR/1.0';

my $creds_extractors = 'Cookie:Guest';

sub sudo_make_me_a_cookie {
    my $name  = shift;
    my $value = shift;
    return "$name=$value";
}

###############################################################################
# TEST: Cookie present, user can authenticate
cookie_ok: {
    # create the cookie data
    local $ENV{HTTP_COOKIE} = sudo_make_me_a_cookie(
        $cookie_name,
        Socialtext::HTTP::Cookie->BuildCookieValue(user_id => $valid_user_id),
    );

    # configure the list of Credentials Extractors to run
    Socialtext::AppConfig->set(credentials_extractors => $creds_extractors);

    # extract the credentials
    my $username = Socialtext::CredentialsExtractor->ExtractCredentials();
    is $username, $valid_user_id, 'extracted credentials from HTTP cookie';
}

###############################################################################
# TEST: Cookie present, but invalid
cookie_invalid: {
    # create the cookie data
    local $ENV{HTTP_COOKIE} = sudo_make_me_a_cookie(
        $cookie_name,
        'THIS-IS-A-BAD-COOKIE',
    );

    # configure the list of Credentials Extractors to run
    Socialtext::AppConfig->set(credentials_extractors => $creds_extractors);

    # extract the credentials
    my $username = Socialtext::CredentialsExtractor->ExtractCredentials();
    is $username, undef, 'unable to extract credentials when cookie invalid';
}

###############################################################################
# TEST: Cookie missing, not authenticated
cookie_missing: {
    # empty cookie
    delete local $ENV{HTTP_COOKIE};

    # configure the list of Credentials Extractors to run
    Socialtext::AppConfig->set(credentials_extractors => $creds_extractors);

    # extract the credentials
    my $username = Socialtext::CredentialsExtractor->ExtractCredentials();
    is $username, undef,
        'unable to extract credentials when cookie is missing';
}

###############################################################################
# TEST: AIR client does NOT share standard HTTP cookie
adobe_air_separate_cookie: {
    # create the cookie data
    my $cookie = sudo_make_me_a_cookie(
        $cookie_name,
        Socialtext::HTTP::Cookie->BuildCookieValue(user_id => $valid_user_id),
    );
    my $air_cookie = sudo_make_me_a_cookie(
        $air_cookie_name,
        Socialtext::HTTP::Cookie->BuildCookieValue(user_id => $valid_user_id),
    );

    # configure the list of Credentials Extractors to run
    Socialtext::AppConfig->set(credentials_extractors => $creds_extractors);

    # pretend to be Adobe AIR
    local $ENV{HTTP_USER_AGENT} = $air_user_agent;

    # TEST: AIR client doesn't get to use standard HTTP cookie
    local $ENV{HTTP_COOKIE} = $cookie;
    my $username = Socialtext::CredentialsExtractor->ExtractCredentials();
    ok !defined $username, 'AIR client does not use regular HTTP cookie';

    # TEST: AIR client uses its own HTTP cookie
    local $ENV{HTTP_COOKIE} = $air_cookie;
    $username = Socialtext::CredentialsExtractor->ExtractCredentials();
    ok $username, 'AIR client uses its own HTTP cookie';
}
