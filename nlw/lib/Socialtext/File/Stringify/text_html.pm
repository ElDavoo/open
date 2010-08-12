# @COPYRIGHT@
package Socialtext::File::Stringify::text_html;
use strict;
use warnings;

use Socialtext::File::Stringify::Default;
use Socialtext::System;

sub to_string {
    my ( $class, $buf_ref, $file, $mime ) = @_;
    my @cmd = "lynx";
    push @cmd, '-dump' => $file;
    Socialtext::System::backtick(@cmd, {stdout => $buf_ref});
    Socialtext::File::Stringify::Default->to_string($buf_ref, $file, $mime)
        if $? or $@;
}

1;

=head1 NAME

Socialtext::File::Stringify::text_html - Stringify HTML documents

=head1 METHODS

=over

=item to_string($filename)

Extracts the stringified content from C<$filename>, an HTML document.

=back

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT

Copyright 2006 Socialtext, Inc., all rights reserved.

=cut
