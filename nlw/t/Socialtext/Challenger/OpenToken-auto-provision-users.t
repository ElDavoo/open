#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use mocked 'Socialtext::WebApp';
use mocked 'Apache::Cookie';
use mocked 'Socialtext::Log', qw(:tests);
use mocked 'Socialtext::Hub';
use MIME::Base64;
use POSIX qw();
use Crypt::OpenToken;
use Socialtext::Challenger::OpenToken;
use Socialtext::User;
use Test::Socialtext tests => 6;

###############################################################################
# Create our test fixtures *OUT OF PROCESS* as we're using a mocked Hub.
BEGIN {
    my $rc = system('dev-bin/make-test-fixture --fixture admin_no_pages');
    $rc >>= 8;
    $rc && die "unable to set up test fixtures!";
}
fixtures(qw( admin_no_pages ));

###############################################################################
# TEST DATA
###############################################################################
our %data = (
    challenge_uri => 'http://www.google.com',
    password      => 'a66C9MvM8eY4qJKyCXKW+19PWDeuc3th',
);

###############################################################################
# auto-create user on first request
auto_create_user: {
    my $email_addr = 'auto-create-user-' . time . $$ . '@ken.socialtext.net';
    my $first_name = 'Auto Created';
    my $last_name  = 'Test User';

    my $rc = _issue_auto_provisioning_challenge(
        with_user => {
            username        => $email_addr,
            email_address   => $email_addr,
            first_name      => $first_name,
            last_name       => $last_name,
        },
    );
    ok $rc, 'challenge was successful';

    # verify that the user exists now
    my $user = Socialtext::User->new(email_address => $email_addr);
    isa_ok $user, 'Socialtext::User', '... auto-provisioned user';

    # verify that *we* created the user
    logged_like 'info', qr/OpenToken: auto-provisioning user '$email_addr'/,
        '... ... which we auto-provisioned';

    # verify that the User was created in the correct account
    is $user->primary_account->name, Socialtext::Account->Default->name,
        '... ... placed in the Default Account';

    # CLEANUP: out of process fixtures don't clean up for us
    $user && Test::Socialtext::User->delete_recklessly($user);
}

###############################################################################
# if we fail to create a new user, we better log an error why
log_failure_to_auto_create_user: {
    my $email_addr = 'invalid-email-address';
    my $first_name = 'Invalid';
    my $last_name  = 'Test User';

    my $rc = _issue_auto_provisioning_challenge(
        with_user => {
            username        => $email_addr,
            email_address   => $email_addr,
            first_name      => $first_name,
            last_name       => $last_name,
        },
    );
    ok !$rc, 'challenge failed (as expected)';

    # verify that we logged that we failed to create the new user
    logged_like 'error', qr/unable to auto-provision new user/,
        '... failed because we failed to create new user record';
}



sub _issue_auto_provisioning_challenge {
    my %args = @_;
    my $user_data = $args{with_user};

    # save the configuration, allowing for explicit over-ride of config text
    my $config = Socialtext::OpenToken::Config->new(
        %data,
        auto_provision_new_users => 1,
    );
    Socialtext::OpenToken::Config->save($config);

    # set a Guest user (so that it *looks like* we're not a valid user)
    my $hub = Socialtext::Hub->new;
    $hub->{current_user} = Socialtext::User->Guest();

    # cleanup prior to test run
    Socialtext::WebApp->clear_instance();
    Apache::Cookie->clear_cookies();
    clear_log();

    # in an OpenToken, the "subject" parameter *is* the username
    $user_data->{subject} = delete $user_data->{username};

    # create an OpenToken to use for the challenge
    my $password = decode_base64($data{password});
    my $factory  = Crypt::OpenToken->new(password => $password);
    my $token   = $factory->create(
        Crypt::OpenToken::CIPHER_AES128,
        $user_data,
    );

    my $token_param = $config->token_parameter;
    local $Apache::Request::PARAMS{$token_param} = $token;

    # issue the challenge
    my $rc = Socialtext::Challenger::OpenToken->challenge(hub => $hub);
    return $rc;
}

sub _make_iso8601_date {
    my $time_t = shift;
    return POSIX::strftime('%Y-%m-%dT%H:%M:%SGMT', gmtime($time_t));
}
