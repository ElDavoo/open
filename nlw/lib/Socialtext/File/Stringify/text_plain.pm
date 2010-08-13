# @COPYRIGHT@
package Socialtext::File::Stringify::text_plain;
use strict;
use warnings;

use Socialtext::File;
use Socialtext::File::Stringify;
use Socialtext::l10n qw/system_locale/;
use Socialtext::Log qw/st_log/;

sub to_string {
    my ( $class, $buf_ref, $filename, $mime ) = @_;
    $$buf_ref = '';

    open my $fh, '<', $filename or return;
    my $data = do { local $/; <$fh> };
    (my $charset) = ($mime =~ /;charset=(\S+)/);
    $charset ||= Socialtext::File::guess_string_encoding(
        system_locale(),\$data);
    warn "USING CHARSET $charset";
    $$buf_ref = eval { Encode::decode($charset,$data) } || '';
    if ($@) {
        st_log()->warning("could not decode attachment charset '$charset': $@'");
    }
    return;
}

1;

=head1 NAME

Socialtext::File::Stringify::text_plain - Stringify text documents

=head1 METHODS

=over

=item to_string($filename)

Extracts the stringified content from C<$filename>, a text document.

=back

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT

Copyright 2006 Socialtext, Inc., all rights reserved.

=cut
