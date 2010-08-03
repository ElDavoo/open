package Socialtext::CredentialsExtractor::SiteMinder;
# @COPYRIGHT@

use strict;
use warnings;

our $USER_HEADER = 'SM_USER';
our $SESS_HEADER = 'SM_SERVERSESSIONID';

sub extract_credentials {
    my ($class, $request) = @_;

    # Make sure that a "SM_SERVERSESSIONID" exists.
    #
    # Don't care what the Session Id is, just that one exists; once the User
    # logs out it is possible to still have an SM_USER header, but there won't
    # be an active Session any more.
    my $session = $request->header_in($SESS_HEADER);
    unless ($session) {
        $request->log_reason("No active SiteMinder session.", $request->uri);
        return;
    }

    # Get the "SM_USER" header; the "username" of the logged in user
    my $username = $request->header_in($USER_HEADER);
    $username =~ s/^[^\\]+\\// if $username; # remove a DOMAIN\ prefix if any
    unless ($username) {
        $request->log_reason("$USER_HEADER header missing or empty", $request->uri);
        return;
    }

    # Done; return the Username.
    return $username;
}

1;

=head1 NAME

Socialtext::CredentialsExtractor::SiteMinder - Extracts SiteMinder credentials

=head1 SYNOPSIS

  # In socialtext.conf
  credentials_extractors: SiteMinder:BasicAuth:Cookie:Guest

=head1 DESCRIPTION

This plugin class trusts the credentials as provided by SiteMinder in the
C<SM_USER> HTTP header.  A valid SiteMinder session (as noted in the
C<SM_SERVERSESSIONID> HTTP header) is also required.

This plugin allows for integration with SiteMinder, when configured to run in
a reverse proxy configuration.

=head1 METHODS

=over

=item B<$extractor-E<gt>extract_credentials($request)>

Returns the Username as previously authenticated by SiteMinder.

=back

=head1 AUTHOR

Socialtext, Inc., C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=head1 SEE ALSO

http://schmurgon.net/blogs/christian/archive/2006/08/13/50.aspx

=cut
