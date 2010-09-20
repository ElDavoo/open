package Test::Socialtext::Cookie;
# @COPYRIGHT@

use strict;
use warnings;
use CGI::Cookie;
use Socialtext::HTTP::Cookie;

sub BuildCookie {
    my $class = shift;
    my $value = Socialtext::HTTP::Cookie->BuildCookieValue(@_);
    my $name  = Socialtext::HTTP::Cookie->cookie_name();
    return join '=', $name, $value;
}

1;

=head1 NAME

Test::Socialtext::Cookie - methods to manipulate cookies within tests

=head1 SYNOPSIS

  use Test::Socialtext::Cookie;

  # create a new Cookie (as a string)
  $cookie = Test::Socialtext::Cookie->BuildCookie(user_id => $user_id);

=head1 DESCRIPTION

This module implements methods to assist with the creation and manipulation of
cookies from within test suites.

=head1 METHODS

=over

=item B<Test::Socialtext::Cookie-E<gt>BuildCookie(%values)>

Creates a new cookie based on the provided C<%values>, returning that cookie
back to the caller as a string.

=back

=cut
