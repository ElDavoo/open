package Socialtext::CredentialsExtractor::SSLCertificate;
# @COPYRIGHT@

use strict;
use warnings;

sub extract_credentials {
    my ($class, $request) = @_;

    my $subject = $request->header_in('X-SSL-Client-Subject-DN');
    my ($username) = ($subject =~ m{/CN=(.+?)/});
    return $username;
}

1;

=head1 NAME

Socialtext::CredentialsExtractor::SSLCertificate - SSL Certificate credentials

=head1 DESCRIPTION

This plugin class trusts the credentials as provided by a Client-Side SSL
Certificate.

It is presumed that the "CN=" attribute in the Subject of the SSL Certificate
is the "username" for the User.

=head1 METHODS

=over

=item B<$extractor-E<gt>extract_credentials($request)>

Returns the Username as indicated in the Client-Side SSL Certificate.

=back

=head1 AUTHOR

Socialtext, Inc., C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Socialtext, Inc.,  All Rights Reserved.

=cut
