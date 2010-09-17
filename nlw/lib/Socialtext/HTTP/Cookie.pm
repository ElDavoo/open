package Socialtext::HTTP::Cookie;

###############################################################################
# Required inclusions.
use strict;
use warnings;
use Class::Field qw(const);
use Digest::SHA qw(sha1_base64);
use Socialtext::AppConfig;
use Socialtext::BrowserDetect;
use CGI::Cookie;

###############################################################################
# Allow some constant values to be exported
use base qw(Exporter);
our %EXPORT_TAGS = (
    constants => [qw( USER_DATA_COOKIE AIR_USER_COOKIE )],
    );
our @EXPORT_OK = map { @{$_} } values %EXPORT_TAGS;

const USER_DATA_COOKIE => 'NLW-user';
const AIR_USER_COOKIE  => 'AIR-user';

###############################################################################
sub cookie_name {
    return Socialtext::BrowserDetect::adobe_air()
        ? AIR_USER_COOKIE()
        : USER_DATA_COOKIE();
}

###############################################################################
our $MAC_secret; # prevent constantly loading socialtext.conf
sub MAC_for_user_id {
    my ($class, $user_id) = @_;
    $MAC_secret ||= Socialtext::AppConfig->MAC_secret;
    return sha1_base64($user_id, $MAC_secret);
}

sub GetValidatedUserId {
    my $class     = shift;
    my $name      = $class->cookie_name();
    my $cookie    = $class->GetRawCookie($name) || '';
    my %user_data = $class->_parse_cookie($cookie);
    return $user_data{user_id}
        if $user_data{user_id}
        and $user_data{MAC}
        and $user_data{MAC} eq $class->MAC_for_user_id($user_data{user_id});
    return 0;
}

sub AuthCookiePresent {
    my $class = shift;
    my $name  = $class->cookie_name();
    return $class->GetRawCookie($name) ? 1 : 0;
}

sub GetRawCookie {
    my $class   = shift;
    my $name    = shift;
    my $cookies = CGI::Cookie->raw_fetch;
    return $cookies->{$name};
}

sub _parse_cookie {
    my $class     = shift;
    my $value     = shift;
    my @user_data = split(/[&;]/, $value);
    push @user_data, undef if (@user_data % 2 == 1);
    return @user_data;
}

sub BuildCookieValueForUserId {
    my $class   = shift;
    my $user_id = shift;
    return {
        user_id => $user_id,
        MAC     => $class->MAC_for_user_id($user_id),
    };
}

1;

=head1 NAME

Socialtext::HTTP::Cookie - HTTP cookie interface

=head1 SYNOPSIS

  use Socialtext::HTTP::Cookie;

  # generate MAC for a User ID
  $mac = Socialtext::HTTP::Cookie->MAC_for_user_id($user_id);

  # determine name of HTTP cookie to use
  $name = Socialtext::HTTP::Cookie->cookie_name();

=head1 DESCRIPTION

C<Socialtext::HTTP::Cookie> provides several methods to assist in the handling
of HTTP cookies.

Before C<Socialtext::HTTP::Cookie>, these methods were scattered around the
code, and some had multiple implementations.

=head1 CONSTANTS

The following constants are available for import either via the C<:constants>
tag (if you want all of them) or by importing them individually:

=over

=item USER_DATA_COOKIE

The name of the HTTP cookie that contains User Authentication information
(NLW-user).

=item AIR_USER_COOKIE

The name of the HTTP cookie that contains User Authentication information
for Adobe AIR clients (AIR-user).

A I<separate> HTTP cookie is used for Adobe AIR clients, as it shares the
cookie store with Internet Explorer; having a separate cookie allows the User
to be logged in separately using Internet Explorer and Socialtext Desktop
(e.g. logging out of one doesn't automatically log you out of the other).

=back

=head1 METHODS

=over

=item B<Socialtext::HTTP::Cookie-E<gt>MAC_for_user_id($user_id)>

Generates a MAC based on the given C<$user_id>, and returns the MAC back to
the caller.

=item B<Socialtext::HTTP::Cookie-E<gt>cookie_name()>

Determines the name of the HTTP cookie to use for the current HTTP request,
returning the cookie name back to the caller.

Cookie name is User-Agent specific, in order to accommodate Adobe AIR sharing
a cookie store with Internet Explorer.

=back

=head1 AUTHOR

Socialtext, Inc.  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2005-2009 Socialtext, Inc., All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
