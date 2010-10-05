package Socialtext::CredentialsExtractor::Extractor::SiteMinder;
# @COPYRIGHT@

use Moose;
with 'Socialtext::CredentialsExtractor::Extractor';

our $USER_HEADER = 'SM_USER';
our $SESS_HEADER = 'SM_SERVERSESSIONID';

sub uses_headers {
    return ($USER_HEADER, $SESS_HEADER);
}

sub extract_credentials {
    my ($class, $hdrs) = @_;

    # Make sure that a "SM_SERVERSESSIONID" exists.
    #
    # Don't care what the Session Id is, just that one exists; once the User
    # logs out it is possible to still have an SM_USER header, but there won't
    # be an active Session any more.
    unless ($hdrs->{$SESS_HEADER}) {
# XXX: exposed warn statement
        warn "No active SiteMinder session.\n";
        return;
    }

    # Get the "SM_USER" header; the "username" of the logged in user
    my $username = $hdrs->{$USER_HEADER};
    $username =~ s/^[^\\]+\\// if $username; # remove a DOMAIN\ prefix if any
    unless ($username) {
# XXX: exposed warn statement
        warn "$USER_HEADER header missing or empty\n";
        return;
    }

    # Get the UserId for the User.
    return $class->username_to_user_id($username);
}

1;

=head1 NAME

Socialtext::CredentialsExtractor::Extractor::SiteMinder - Extract creds from SiteMinder reverse proxy headers

=head1 SYNOPSIS

  # see Socialtext::CredentialsExtractor

=head1 DESCRIPTION

This module extracts credentials from the HTTP headers provided by a SiteMinder reverse proxy.

=head1 SEE ALSO

L<Socialtext::CredentialsExtractor::Extractor>,
http://schmurgon.net/blogs/christian/archive/2006/08/13/50.aspx

=cut
