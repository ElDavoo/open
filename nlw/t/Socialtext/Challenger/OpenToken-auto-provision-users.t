#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use lib '/home/graham/src/customer-one-offs/crypt-opentoken/lib';
use mocked 'Socialtext::WebApp';
use mocked 'Apache::Cookie';
use mocked 'Socialtext::Log', qw(:tests);
use mocked 'Socialtext::Hub';
use POSIX qw();
use Crypt::OpenToken;
use Socialtext::Challenger::OpenToken;
use File::Slurp qw(write_file);
use Socialtext::User;
#use Test::Socialtext tests => 30;
use Test::Socialtext skip_all => "HAVEN'T WRITTEN USER AUTO-VIVIFICATION YET";

###############################################################################
# Create our test fixtures *OUT OF PROCESS* as we're using a mocked Hub.
BEGIN {
    my $rc = system('dev-bin/make-test-fixture --fixture admin_no_pages');
    $rc >>= 8;
    $rc && die "unable to set up test fixtures!";
}

###############################################################################
# TEST DATA
###############################################################################
our %data = (
    challenge_uri => 'http://www.google.com',
    password      => 'a66C9MvM8eY4qJKyCXKW+19PWDeuc3th',
);

=pod

###############################################################################
# auto-create user on first request
auto_create_user: {
    # write out config
    ok $config->save(), 'saved configuration';

    # forcably delete the user, and then make sure that he doesn't exist
    my $user = Socialtext::User->new(email_address => $data{fields}{email_address});
    $user && Test::Socialtext::User->delete_recklessly($user);

    $user = Socialtext::User->new(email_address => $data{fields}{email_address});
    ok !$user, 'user does not exist (yet)';

    # cleanup, prior to the test
    clear_log();

    # issue the challenge
    my $params = {
        ticket  => $data{encrypted},
        iv      => $data{init_vector},
    };
    my $req = Apache::Request->new( params => $params );
    my $hub = Socialtext::Hub->new();
    my $rc  = Socialtext::Challenger::Spacesaver->challenge(
        hub     => $hub,
        request => $req,
        );
    ok $rc, 'challenge was successful';

    # verify that the user exists now
    $user = Socialtext::User->new(email_address => $data{fields}{email_address});
    isa_ok $user, 'Socialtext::User', '... auto-created user';

    # verify that *we* created the user
    logged_like 'notice', qr/unable to find user \S+, creating/, '... ... and *we* were the ones to create the user';

    # CLEANUP: out of process fixtures don't clean up for us
    $user && Test::Socialtext::User->delete_recklessly($user);
}

=pod

###############################################################################
# auto-created User goes into Default Account
auto_created_user_placed_in_default_account: {
    # write out config
    ok $config->save(), 'saved configuration';

    # forcably delete the user, and then make sure that he doesn't exist
    my $user = Socialtext::User->new(email_address => $data{fields}{email_address});
    $user && Test::Socialtext::User->delete_recklessly($user);

    $user = Socialtext::User->new(email_address => $data{fields}{email_address});
    ok !$user, 'user does not exist (yet)';

    # cleanup, prior to the test
    clear_log();

    # issue the challenge
    my $params = {
        ticket  => $data{encrypted},
        iv      => $data{init_vector},
    };
    my $req = Apache::Request->new( params => $params );
    my $hub = Socialtext::Hub->new();
    my $rc  = Socialtext::Challenger::Spacesaver->challenge(
        hub     => $hub,
        request => $req,
        );
    ok $rc, 'challenge was successful';

    # verify that the user exists now, and that he's in the Default Account
    $user = Socialtext::User->new(email_address => $data{fields}{email_address});
    isa_ok $user, 'Socialtext::User', '... auto-created user';
    is $user->primary_account_id, Socialtext::Account->Default->account_id,
        '... ... and placed in default account';

    # CLEANUP: out of process fixtures don't clean up for us
    $user && Test::Socialtext::User->delete_recklessly($user);
}

=pod

###############################################################################
# if we fail to create a new user, we better log an error why
log_failure_to_auto_create_user: {
    # write out config
    ok $config->save(), 'saved configuration';

    # create new Ticket for our test user, who will *fail* to create
    my %proto_user = (
        first_name    => 'Test',
        last_name     => 'User',
        username      => '123456789',
        email_address => 'invalid-email-address',
    );
    my $factory = Socialtext::SSO::Spacesaver::TicketFactory->new(
        shared_key  => $data{shared_key},
    );
    my $ticket = $factory->create( %proto_user );
    ok $ticket, 'created ticket for test user (with invalid e-mail address)';

    # cleanup, prior to the test
    clear_log();
    Apache::Cookie->clear_cookies();

    # issue challenge, verify that we failed
    my $params = {
        ticket  => $ticket->encrypted,
        iv      => $ticket->init_vector,
    };
    my $req = Apache::Request->new( params => $params );
    my $hub = Socialtext::Hub->new();
    my $rc  = Socialtext::Challenger::Spacesaver->challenge(
        hub     => $hub,
        request => $req,
    );
    ok !$rc, '... challenge failed (as expected)';

    # verify that we logged that we failed to create the new user
    logged_like 'error', qr/failed to create user/, '... ... failed because we failed to create new user record';
}

=cut
















sub _issue_challenge {
    my %args = @_;
    my $user          = $args{with_user};
    my $config_text   = $args{with_config};
    my $with_token    = $args{with_token};
    my $resource_url  = $args{with_resource_url};
    my $challenge_uri = $args{with_challenge_uri};
    my $token_data    = $args{with_token_data} || {};

    # save the configuration, allowing for explicit over-ride of config text
    local $data{challenge_uri} = $challenge_uri if ($challenge_uri);
    my $config = Socialtext::OpenToken::Config->new(%data);
    Socialtext::OpenToken::Config->save($config);

    if ($config_text) {
        write_file(
            Socialtext::OpenToken::Config->config_filename,
            $config_text,
        );
    }

    # set the test user
    my $hub = Socialtext::Hub->new;
    $hub->{current_user} = $user;

    # cleanup prior to test run
    Socialtext::WebApp->clear_instance();
    Apache::Cookie->clear_cookies();
    clear_log();

    # create an OpenToken to use for the challenge
    my $token;
    if ($with_token) {
        my $factory = Crypt::OpenToken->new(password => $data{password});
        $token = $factory->create(
            Crypt::OpenToken::CIPHER_AES128,
            {
                subject  => $user->username,
                ($resource_url ? (resource_url=>$resource_url) : ()),
                %{$token_data},
            },
        );
    }
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
