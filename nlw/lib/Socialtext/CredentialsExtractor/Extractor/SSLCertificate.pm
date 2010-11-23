package Socialtext::CredentialsExtractor::Extractor::SSLCertificate;

use Moose;
with 'Socialtext::CredentialsExtractor::Extractor';

use Net::LDAP::Util qw(ldap_explode_dn);

sub uses_headers {
    return qw(
        X_SSL_CLIENT_SUBJECT
    );
}

sub extract_credentials {
    my ($class, $hdrs) = @_;

    # Get the Subject DN from the headers, and normalize its format.
    my $subject = $hdrs->{X_SSL_CLIENT_SUBJECT};
    $subject =~ s{^/\s*}{}g;        # eliminate leading '/'s
    $subject =~ s{/\s*}{, }g;       # convert '/'s to ','s
    # XXX: doesn't accommodate "..., ..., .../..." (embedded slashes)

    # Split the subject up into its component fields.
    my $fields = ldap_explode_dn($subject);

    # Grab the field that contains the Username in it
    my $user_field = 'CN';
    my ($username) =
        map  { $_->{$user_field} }
        grep { exists $_->{$user_field} }
        @{$fields};

    my $user_id = $class->username_to_user_id($username);
    return $class->valid_creds(user_id => $user_id) if ($user_id);
    return $class->invalid_creds(reason => "invalid username: $username");
}

no Moose;

1;

=head1 NAME

Socialtext::CredentialsExtractor::Extractor::SSLCertificate - Extract creds from Client-Side SSL Certificate

=head1 SYNOPSIS

  # see Socialtext::CredentialsExtractor

=head1 DESCRIPTION

This module extracts credentials from a Client-Side SSL Certificate subject.

It is presumed that the certificate has already been verified/validated before
hand; this credentials extractor simply pulls the Username out of the
certificate subject and confirms that this is a known User.

=head1 SEE ALSO

L<Socialtext::CredentialsExtractor::Extractor>

=cut
