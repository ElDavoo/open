package Socialtext::CGI::User;
# @COPYRIGHT@

use strict;
use warnings;
use Digest::SHA;
use CGI::Cookie;
use Socialtext::Apache::User;
use Socialtext::HTTP::Cookie;

use base 'Exporter';
our @EXPORT_OK = qw/get_current_user/;

# Note: A parallel version of this code lives in Socialtext::Apache::User
# so if this mechanism changes, we need to change the CGI version too
# (or merge them together).
#
# This one is used by reports and the appliance console

sub get_current_user {
    my $name_or_id = _user_id_or_username() || return;
    return Socialtext::Apache::User::_current_user($name_or_id);
}

sub _user_id_or_username {
    my $user_id = Socialtext::HTTP::Cookie->GetValidatedUserId();
    return $user_id;
}

1;

=head1 NAME

Socialtext::CGI::User - Extract Socialtext user information from a CGI request

=head1 SYNOPSIS

  use Socialtext::CGI::User qw(get_current_user);

  $user = get_current_user();

=head1 DESCRIPTION

C<Socialtext::CGI::User> provides some helper methods to get information on
the current User.  B<Only> to be used in CGI scripts; use
C<Socialtext::Apache::User> if you are running under Mod_perl.

B<NOTE:> a parallel version of this code lives in C<Socialtext::Apache::User>.
If this mechanism changes, we need to change the Apache version too.
Eventually we'd like to merge them together into a single API, but we haven't
gotten there yet.

=head1 METHODS

=over

=item B<get_current_user()>

Returns a C<Socialtext::User> object for the currently authenticated User.

=back

=head1 AUTHOR

Socialtext, Inc., C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Socialtext, Inc. All Rights Reserved.

=cut
