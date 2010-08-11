# @COPYRIGHT@
package Socialtext::File::Stringify;
use strict;
use warnings;

use Socialtext::MIME::Types ();
use Socialtext::System;
use Socialtext::File::Stringify::Default;
use Socialtext::Encode;
use Socialtext::File qw/mime_type/;
use File::Temp qw/tempdir/;
use File::chdir;
use File::Path qw/rmtree/;

sub to_string {
    my ( $class, $filename, $type ) = @_;
    return "" unless defined $filename;

    $filename = Cwd::abs_path($filename);

    $type ||= mime_type($filename, $filename);

    # some stringifiers emit a bunch of junk into the cwd/$HOME
    # (I'm looking at you, ELinks)
    my $tmpdir = tempdir(CLEANUP=>1);
    my $text;
    {
        local $ENV{HOME} = $tmpdir;
        local $CWD = $tmpdir;

        # default 5 minute timeout for backticked scripts
        local $Socialtext::System::TIMEOUT = 300;
        # default 2 GiB (minus 4kiB) virtual memory space for backticked scripts.
        # subtract 4kiB so we don't overflow a 32-bit signed integer.
        local $Socialtext::System::VMEM_LIMIT = (2 * 2**30) - 4096;

        my $convert_class = $class->_load_class_by_mime_type($type);
        $text = $convert_class->to_string($filename, $type);
    }

    # Proactively cleanup, to avoid temp files left by long running processes
    rmtree $tmpdir;

    return Socialtext::Encode::ensure_is_utf8($text);
}

{
    my $openxml = 'application/vnd.openxmlformats-officedocument';
    my %special_converters = (
        # MS Office 2007 types
        "$openxml.wordprocessingml.document"   => "Tika",
        "$openxml.presentationml.presentation" => "Tika",
        "$openxml.spreadsheetml.sheet"         => "Tika",

        'audio/mpeg'                    => 'audio_mpeg',
        'application/octet-stream'      => 'application_octet_stream',
        'application/pdf'               => 'application_pdf',
        'application/postscript'        => 'application_postscript',
        'application/vnd.ms-powerpoint' => 'application_vnd_ms_powerpoint',
        'application/vnd.ms-excel'      => 'application_vnd_ms_excel',
        'application/x-msword'          => 'application_x_msword',
        'application/xml'               => 'application_xml',
        'application/zip'               => 'application_zip',
        'text/html'                     => 'text_html',
        'text/plain'                    => 'text_plain',
        'text/rtf'                      => 'text_rtf',
    );
    sub _load_class_by_mime_type {
        my ($class, $type) = @_;

        my $default = join('::', $class, 'Default');
        return $default unless $type;

        my $converter = $special_converters{$type} || 'Default';
        my $class_name = join('::', $class, $converter);

        eval "use $class_name;";
        return $@ ? $default : $class_name;
    }
}

1;
__END__

=pod

=head1 NAME

Socialtext::File::Stringify - Convert various file types to strings.

=cut

=head1 SUBROUTINES

=head2 to_string ( filename, [type] )

The file's MIME type is computed and used to dispatch to a specific method
that knows how to convert files of that type.  If type is passed in then it
overrides what MIME::Type would return.

=head1 SEE ALSO

L<Socialtext::MIME::Types>, L<Socialtext::File::Stringify::*>

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT

Copyright 2006 Socialtext, Inc., all rights reserved.

=cut
