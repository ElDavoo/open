package Socialtext::CredentialsExtractor::Extractor::Guest;

use Moose;
with 'Socialtext::CredentialsExtractor::Extractor';

use Socialtext::User;

sub uses_headers { }

sub extract_credentials {
    return Socialtext::User->Guest->user_id();
}

1;

=head1 NAME

Socialtext::CredentialsExtractor::Extractor::Guest - Guest credentials

=head1 SYNOPSIS

  # see Socialtext::CredentialsExtractor

=head1 DESCRIPTION

This module B<always> returns "Guest" credentials.

=head1 SEE ALSO

L<Socialtext::CredentialsExtractor::Extractor>

=cut