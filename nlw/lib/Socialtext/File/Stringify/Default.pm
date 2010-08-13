# @COPYRIGHT@
package Socialtext::File::Stringify::Default;
use strict;
use warnings;

use Socialtext::System;
use Socialtext::MIME::Types;

our $blacklist_type = qr{(?:
    application/(?:
        x-dosexec |
        x-msdos-program |
        x-apple-diskimage |
        x-bzip2 |
        x-gzip |
        x-.*tar.* |
        binary | octet-stream # don't stringify unknown types
    ) |
    image/.* |
    video/.* |
    audio/.*
)$}x; # just end-anchor

sub to_string {
    my ( $class, $buf_ref, $filename, $mime ) = @_;

    # These produce huge output that is 99% not useful, so just do nothing.
    return "" if $mime =~ $blacklist_type;

    Socialtext::System::backtick('strings', $filename,
        { stdout => $buf_ref });
}

1;

=head1 NAME

Socialtext::File::Stringify::Default - Default stringifier

=head1 DESCRIPTION

Default stringifier, when nothing else is willing to handle it.

=head1 METHODS

=over

=item to_string($filename)

Extracts the stringified content from C<$filename>, using F<strings>.

=back

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT

Copyright 2006 Socialtext, Inc., all rights reserved.

=cut
