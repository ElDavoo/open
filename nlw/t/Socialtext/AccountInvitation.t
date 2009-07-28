#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 4;
use Email::Send::Test;
use Socialtext::Account;
use Socialtext::User;

BEGIN {
    use_ok( 'Socialtext::AccountInvitation' );
}

fixtures( 'db' );

$Socialtext::EmailSender::Base::SendClass = 'Test';

my $acct = create_test_account_bypassing_factory();
my $from = create_test_user( unique_id => 'invitor', account => $acct );

Simple_case: {
    my $invitee_email = 'invitee@example.com';
    my $invitation = Socialtext::AccountInvitation->new(
        account   => $acct,
        from_user => $from,
        invitee   => $invitee_email,
    );

    eval { $invitation->send(); };
    my $e = $@;
    is $e, '', 'account invite sent';

    my $invitee = Socialtext::User->new( email_address => $invitee_email );
    ok $invitee, 'user created';
    is $invitee->primary_account_id, $acct->account_id, 'user in correct acct';
}
