#!/usr/bin/env perl

use strict;
use warnings;
use File::Slurp qw(slurp);
use Socialtext::CredentialsExtractor;
use Socialtext::CredentialsExtractor::Extractor::CAC;
use Socialtext::AppConfig;
use Socialtext::Signal;
use Test::Socialtext tests => 50;
use Test::Socialtext::User;

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
# TEST: Find partially provisioned Users.
find_partially_provisioned_users: {
    my %fields = (
        first_name  => 'David',
        middle_name => 'Michael',
        last_name   => 'Smith',
    );

    # Two matching UN-provisioned Users, non-matching UN-provisioned User, and
    # a provisioned User.
    my $user_one = create_test_user(%fields);
    $user_one->add_restriction('require_external_id');

    my $user_two = create_test_user(%fields);
    $user_two->add_restriction('require_external_id');

    my $diff_name_user = create_test_user(%fields, middle_name => 'Matt');
    $diff_name_user->add_restriction('require_external_id');

    my $provisioned_user = create_test_user(%fields);

    # Which Users did we find?
    my @users = Socialtext::CredentialsExtractor::Extractor::CAC
        ->_find_partially_provisioned_users(
            first_name  => 'David',
            middle_name => 'Michael',
            last_name   => 'Smith',
        );
    my @found    = map { $_->username } @users;
    my @expected = map { $_->username } ($user_one, $user_two);
    is_deeply \@found, \@expected, 'Found partially provisioned Users';
}

###############################################################################
# TEST: Send notification to Business Admins
notify_business_admins: {
    my $user = create_test_user;
    $user->set_business_admin(1);

    my @badmins = Socialtext::User->AllBusinessAdmins->all;
    ok @badmins, 'Have at least one Business Admin';
    ok grep( { $_->user_id == $user->user_id } @badmins),
        '... including our Test User';

    # Check first that our target User has *no* Signals in their stream
    my @signals = Socialtext::Signal->All(
        viewer => $user,
        direct => 'received',
    );
    ok !@signals, '... no Signals in the stream (yet)';

    # Send a notification message to all Business Admins on the box
    my $subject = 'This is a test';
    my $body    = '... of the emergency broadcast system';
    Socialtext::CredentialsExtractor::Extractor::CAC->_send_notification(
        recipients => \@badmins,
        username   => 'failing.cac.login.username',
        subject    => $subject,
        body       => $body,
    );

    # Get the DM Signal sent to our test User, and verify its contents
    @signals = Socialtext::Signal->All(
        viewer => $user,
        direct => 'received',
    );
    is @signals, 1, '... found a Signal sent to User';

    my $sig = shift @signals;
    is $sig->recipient_id, $user->user_id, '... ... a DM to this User';
    is $sig->user_id,      $user->user_id, '... ... from himself';
    is $sig->body, $subject, '... ... with our message';

    my $atts = $sig->attachments;
    is @{$atts}, 1, '... ... and an attachment';

    my $att      = shift @{$atts};
    my $file     = $att->upload->disk_filename;
    my $contents = slurp($file);
    is $contents, $body, '... ... ... with correct attachment contents';
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

###############################################################################
# TEST: Auto-provision User, single User matches
auto_provision_user: {
    my $guard  = Test::Socialtext::User->snapshot;
    my $first  = 'Ian';
    my $middle = 'Lancaster';
    my $last   = 'Fleming';
    my $edipin = time;

    # Create a User, flag them as being partially provisioned.
    my $user = create_test_user(
        first_name  => $first,
        middle_name => $middle,
        last_name   => $last,
    );
    ok $user, 'Created test User';
    $user->add_restriction('require_external_id');
    ok $user->requires_external_id, '... missing their external id';

    # Extract creds for this User
    my $subject = "C=UK, O=Goldeneye, CN=$first\.$middle\.$last\.$edipin";
    my $creds   = Socialtext::CredentialsExtractor->ExtractCredentials( {
        X_SSL_CLIENT_SUBJECT => $subject,
    } );
    ok $creds->{valid}, 'extracted creds for partially provisioned User';
    is $creds->{user_id}, $user->user_id, '... with correct User';

    $user->reload;
    ok !$user->requires_external_id, '... external id no longer required';
    is $user->private_external_id, $edipin, '... and with assigned EDIPIN';
}

###############################################################################
# TEST: Auto-provision User, multiple User matches
auto_provision_multiple_users: {
    my $guard  = Test::Socialtext::User->snapshot;
    my $first  = 'Lois';
    my $middle = 'Ruth';
    my $last   = 'Hooker';
    my $edipin = time;

    # Create a Business Admin to receive error notifications
    my $badmin = create_test_user;
    $badmin->set_business_admin(1);

    # Create *multiple* Users, all of which are only partially provisioned.
    my $user_one = create_test_user(
        first_name  => $first,
        middle_name => $middle,
        last_name   => $last,
    );
    $user_one->add_restriction('require_external_id');

    my $user_two = create_test_user(
        first_name  => $first,
        middle_name => $middle,
        last_name   => $last,
    );
    $user_two->add_restriction('require_external_id');

    # Attempt to extract creds
    my $subject = "C=UK, O=Goldeneye, CN=$first\.$middle\.$last\.$edipin";
    my $creds   = Socialtext::CredentialsExtractor->ExtractCredentials( {
        X_SSL_CLIENT_SUBJECT => $subject,
    } );
    ok !$creds->{valid}, 'unable to extract credentials';
    like $creds->{reason}, qr/invalid username/, '... invalid username';

    # Verify that the Business Admin got a DM
    my @signals = Socialtext::Signal->All(
        viewer => $badmin,
        direct => 'both',
    );
    is @signals, 1, '... DM Signal was sent to Business Admin';
    like $signals[0]->body, qr/multiple matches found/i,
        '... ... denoting multiple matches being found';

    # Verify contents of DM attachment
    my $att      = $signals[0]->attachments->[0];
    my $file     = $att->upload->disk_filename;
    my $contents = slurp($file);
    like $contents, qr/First name.*?: $first/,   '... ... ... w/first name';
    like $contents, qr/Middle name.*?: $middle/, '... ... ... w/middle name';
    like $contents, qr/Last name.*?: $last/,     '... ... ... w/last name';

    my $found_one = $user_one->name_and_email;
    my $found_two = $user_two->name_and_email;
    like $contents, qr/Found: \Q$found_one\E/, '... ... ... w/first match';
    like $contents, qr/Found: \Q$found_two\E/, '... ... ... w/second match';
}

###############################################################################
# TEST: Auto-provision User, *no* matches
auto_provision_no_users: {
    my $guard = Test::Socialtext::User->snapshot;
    my $first  = 'Thomas';
    my $middle = 'Sean';
    my $last   = 'Connery';
    my $edipin = time;

    # Create a Business Admin to receive error notifications
    my $badmin = create_test_user;
    $badmin->set_business_admin(1);

    # Attempt to extract creds for a non-existing User.
    my $subject = "C=UK, O=Goldeneye, CN=$first\.$middle\.$last\.$edipin";
    my $creds   = Socialtext::CredentialsExtractor->ExtractCredentials( {
        X_SSL_CLIENT_SUBJECT => $subject,
    } );
    ok !$creds->{valid}, 'unable to extract credentials';
    like $creds->{reason}, qr/invalid username/, '... invalid username';

    # Verify that the Business Admin got a DM
    my @signals = Socialtext::Signal->All(
        viewer => $badmin,
        direct => 'both',
    );
    is @signals, 1, '... DM Signal was sent to Business Admin';
    like $signals[0]->body, qr/no matches found/i,
        '... ... denoting NO matches found';

    # Verify contents of DM attachment
    my $att      = $signals[0]->attachments->[0];
    my $file     = $att->upload->disk_filename;
    my $contents = slurp($file);
    like $contents, qr/First name.*?: $first/,   '... ... ... w/first name';
    like $contents, qr/Middle name.*?: $middle/, '... ... ... w/middle name';
    like $contents, qr/Last name.*?: $last/,     '... ... ... w/last name';
}

###############################################################################
# TEST: Throttling of notification Signals
notification_throttling: {
    my $guard = Test::Socialtext::User->snapshot;
    my $first  = 'Roger';
    my $middle = 'George';
    my $last   = 'Moore';
    my $edipin = time;

    # Create a Business Admin to receive error notifications
    my $badmin = create_test_user;
    $badmin->set_business_admin(1);

    # Make multiple attempts to extract creds for this User.
    my $subject = "C=UK, O=Moonraker, CN=$first\.$middle\.$last\.$edipin";
    Socialtext::CredentialsExtractor->ExtractCredentials( {
        X_SSL_CLIENT_SUBJECT => $subject,
    } );
    Socialtext::CredentialsExtractor->ExtractCredentials( {
        X_SSL_CLIENT_SUBJECT => $subject,
    } );
    Socialtext::CredentialsExtractor->ExtractCredentials( {
        X_SSL_CLIENT_SUBJECT => $subject,
    } );
    pass 'Made multiple attempts to extract credentials';

    # Verify that the Business Admin got one (and ONLY one) DM
    my @signals = Socialtext::Signal->All(
        viewer => $badmin,
        direct => 'both',
    );
    is @signals, 1, '... a single DM Signal was sent to Business Admin';
    like $signals[0]->body, qr/no matches found/i,
        '... ... denoting NO matches found';

    # Verify contents of DM attachment
    my $att      = $signals[0]->attachments->[0];
    my $file     = $att->upload->disk_filename;
    my $contents = slurp($file);
    like $contents, qr/First name.*?: $first/,   '... ... ... w/first name';
    like $contents, qr/Middle name.*?: $middle/, '... ... ... w/middle name';
    like $contents, qr/Last name.*?: $last/,     '... ... ... w/last name';
}
