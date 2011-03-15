package Socialtext::CredentialsExtractor::Extractor::CAC;

use Moose;
extends 'Socialtext::CredentialsExtractor::Extractor::SSLCertificate';

use MooseX::ClassAttribute;
use List::MoreUtils qw(any);
use Socialtext::l10n qw(loc);
use Socialtext::Log qw(st_log);
use Socialtext::Signal;
use Socialtext::Signal::Attachment;
use Socialtext::SQL qw(:exec :time);
use Socialtext::Upload;

# How often do we send notifications (in minutes)?
class_has 'notification_frequency' => (
    is      => 'ro',
    isa     => 'Int',
    default => 5,
);

# Regardless of what our parent class says, our username comes from the "CN".
override '_username_field' => sub {
    return 'CN';
};

override 'username_to_user_id' => sub {
    my $class    = shift;
    my $username = shift;
    my $user;

    # Extract all of the fields out of the username, failing if unable
    my %fields = $class->_parse_cac_username($username);
    return unless %fields;

    # Look for an exact match by EDIPIN
    my $edipin = $fields{edipin};
    unless ($edipin) {
        # XXX - warn about SSL subject w/o edipin
        return;
    }
    $user = Socialtext::User->new(private_external_id => $edipin);
    return $user->user_id if $user;

    # Look for a partially provisioned User, by FN/MN/LN
    my @users = $class->_find_partially_provisioned_users(%fields);
    if (@users == 1) {
        # Found matching User; update w/EDIPIN and remove restriction
        $user = shift @users;
        $user->update_private_external_id($edipin);
        $user->remove_restriction('require_external_id');
        return $user->user_id;
    }

    my $err_msg;
    my $err_body = qq|
Searched for:
  First name.: $fields{first_name}
  Middle name: $fields{middle_name}
  Last name..: $fields{last_name}
|;
    if (@users == 0) {
        $err_msg = loc(
            'error.no-user-matched=name',
            $username,
        );
    }
    if (@users > 1) {
        $err_msg = loc(
            'error.multiple-user-matched=name',
            $username,
        );
        foreach my $match (@users) {
            $err_body .= "Found: " . $match->name_and_email . "\n";
        }
    }

    # Notify *all* of the Business Admin's on the box about the failure
    $class->_notify_business_admins(
        username        => $username,
        message         => $err_msg,
        attachment_body => $err_body,
    );

    return;
};

sub _parse_cac_username {
    my $class    = shift;
    my $username = shift;
    my ($first, $middle, $last, $edipin) = split /\./, $username, 4;
    return unless ($first && $middle && $last && $edipin);
    return (
        first_name  => $first,
        middle_name => $middle,
        last_name   => $last,
        edipin      => $edipin,
    );
}

sub _find_partially_provisioned_users {
    my $class  = shift;
    my %fields = @_;

    # Find all matching Users, and trim that to *just* those that have an
    # outstanding "require_external_id" restriction.
    my @users =
        grep { $_->requires_external_id }
        Socialtext::User->Query( {
            first_name  => $fields{first_name},
            middle_name => $fields{middle_name},
            last_name   => $fields{last_name},
        } )->all;

    return @users;
}

sub _notify_business_admins {
    my $class  = shift;
    my %params = @_;
    my $username = $params{username};
    my $subject  = $params{message};
    my $body     = $params{attachment_body};

    # If we've *recently* sent a notification for this Username, don't send
    # another one; throttle ourselves to "one notification every 'n' seconds".
    return if ($class->_notification_recently_sent_for($username));

    # Dump the attachment body to file, so we can slurp it in and create an
    # Upload
    my $tmpfile = File::Temp->new(CLEANUP => 1);
    $tmpfile->print($body);
    $tmpfile->close;

    # Send a DM Signal to all of the Business Admins, with our attachment.
    #
    # NOTE: The DM has to come *FROM* the Business Admin *TO* himself; we've
    # got no other guarantee of visibility from any other User record to the
    # Business Admin.
    my $now     = Socialtext::Date->now;
    my @badmins = Socialtext::User->AllBusinessAdmins->all;
    foreach my $user (@badmins) {
        my $creator = $user;

        my $upload = Socialtext::Upload->Create(
            created_at    => $now,
            creator       => $creator,
            temp_filename => "$tmpfile",
            filename      => 'cac-provisioning-errors.txt',
            mime_type     => 'text/plain; charset=UTF-8',
        );

        my $attachment = Socialtext::Signal::Attachment->new(
            attachment_id => $upload->attachment_id,
            upload        => $upload,
            signal_id     => 0,
        );

        my $signal = Socialtext::Signal->Create( {
            user         => $creator,
            user_id      => $creator->user_id,
            body         => $subject,
            recipient_id => $user->user_id,
            attachments  => [$attachment],
            annotations  => [
                { cac => { subject => $username } },
            ],
        } );
    }

    return;
}

sub _notification_recently_sent_for {
    my $class     = shift;
    my $username  = shift;
    my $frequency = $class->notification_frequency;
    my $threshold = DateTime->now->subtract(minutes => $frequency);

    # Look in the *DB* and see if we have any recent Signals that have been
    # sent w.r.t. the given $username.
    #
    # We have to look in the DB for this instead of using ST::Signal::Search,
    # as the Signal may not yet be indexed in Solr.
    my $sth = sql_execute(qq|
        SELECT signal_id
          FROM signal
         WHERE signal.at >= ?
           AND anno_blob ~* ?
    |, sql_format_timestamptz($threshold), $username);

    while (my $row = $sth->fetchrow_arrayref) {
        my $signal_id = $row->[0];
        my $signal    = Socialtext::Signal->Get(signal_id => $signal_id);
        my $annots    = $signal->annotations;
        return 1 if any { $_->{cac}{subject} eq $username } @{$annots};
    }

    # Didn't find a Signal with our annotation in the DB; wasn't recently sent
    return 0;
}

no Moose;

1;

=head1 NAME

Socialtext::CredentialsExtractor::Extractor::CAC - Extract creds from a CAC subject

=head1 SYNOPSIS

  # see Socialtext::CredentialsExtractor

=head1 DESCRIPTION

This module extracts credentials from a CAC subject (a specially formatted
Client-Side SSL Certificate).

It is presumed that the SSL Certificate used to provide the CAC subject has
already been verified/validated before hand; this credentials extractor simply
pulls the Username out of the certificate subject and confirms that this is a
known User.

=head1 EDIPIN EXTRACTION

The EDIPIN is is encoded in the Subject of the Client-Side SSL Certificate, looking something like:

  C=US, O=U.S. Government, ..., CN=<last>.<first>.<middle>.<edipin>

This module takes the <CN> extracted from the subject, and extracts the last
portion of it as an EDIPIN.

=head1 SEE ALSO

L<Socialtext::CredentialsExtractor::Extractor>,
L<Socialtext::CredentialsExtractor::Extractor::SSLCertificate>,

=cut
