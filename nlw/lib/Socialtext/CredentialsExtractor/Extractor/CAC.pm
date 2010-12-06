package Socialtext::CredentialsExtractor::Extractor::CAC;

use Moose;
extends 'Socialtext::CredentialsExtractor::Extractor::SSLCertificate';

# Regardless of what our parent class says, our username comes from the "CN".
override '_username_field' => sub {
    return 'CN';
};

# Wrap around this so we can extract the EDIPIN
around '_username_from_subject' => sub {
    my $orig     = shift;
    my $username = $orig->(@_);

    if ($username) {
        ($username) = ($username =~ m{\.([^\.]+)$});
    }
    return $username;
};

# Over-ride so we *ONLY* do User lookup by EDIPIN.
override 'username_to_user_id' => sub {
    my $class  = shift;
    my $edipin = shift;
    return unless $edipin;

    my $user = Socialtext::User->new(private_external_id => $edipin);
    return $user->user_id if $user;
    return;
};

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
