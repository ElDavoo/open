# @COPYRIGHT@
package Socialtext::File::Stringify::application_zip;
use strict;
use warnings;

use File::Find;
use File::Path;
use File::Temp;

use Socialtext::File::Stringify;
use Socialtext::File::Stringify::Default;
use Socialtext::System;

sub to_string {
    my ( $class, $buf_ref, $file, $mime ) = @_;

    # Unpack the zip file in a temp dir.
    my $tempdir = File::Temp::tempdir( CLEANUP => 1 );
    Socialtext::System::backtick( "unzip", '-P', '', "-q", $file, "-d", $tempdir, {stdout => \undef} );
    return _default($buf_ref, $file, $mime) if $@;

    # Find all the files we unpacked.
    my @files;
    find sub {
        push @files, $File::Find::name if -f $File::Find::name;
    }, $tempdir;

    # Stringify each the files we found
    $$buf_ref = "";
    for my $f (@files) {
        my $file_buf;
        Socialtext::File::Stringify->to_string(\$file_buf, $f);
        $$buf_ref .= "\n\n========== $f ==========\n\n$$file_buf" if $$file_buf;
    }

    # Cleanup and return the text if we got any, 'else use the default.
    File::Path::rmtree($tempdir);
    _default($buf_ref, $file, $mime) unless $$buf_ref;
    return;
}

sub _default { Socialtext::File::Stringify::Default->to_string(@_) }

1;

=head1 NAME

Socialtext::File::Stringify::application_zip - Stringify contents of Zip files

=head1 METHODS

=over

=item to_string($filename)

Recursively extracts the stringified content of B<all> of the documents
contained within the given C<$filename>, a Zip archive.

=back

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT

Copyright 2006 Socialtext, Inc., all rights reserved.

=cut
