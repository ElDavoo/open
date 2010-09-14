# @COPYRIGHT@
package Socialtext::CredentialsExtractor::Cookie;

use strict;
use warnings;

use Socialtext::HTTP::Cookie;

sub extract_credentials {
    my $class   = shift;
    my $request = shift;
    my $user_id = Socialtext::HTTP::Cookie->GetValidatedUserId();

    # GetValidatedUserId() returns "0" on failure, but *we* need to return
    # undef.  Handle/map that appropriately.
    return $user_id if $user_id;
    return;
}

1;

__END__

=head1 NAME

Socialtext::CredentialsExtractor::Cookie - a credentials extractor plugin

=head1 DESCRIPTION

This plugin class will look in the browser's provided cookies for the User
Authentication information cookie and attempt to extract and return a user_id
from it.

=head1 METHODS

=head2 $extractor->extract_credentials( $request )

Return the value for the User Authentication information cookie or undef.

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Socialtext, Inc., All Rights Reserved.

=cut
