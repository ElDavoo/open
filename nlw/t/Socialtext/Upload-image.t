#!perl
use warnings;
use strict;
use Test::Socialtext;
use Test::More;
use File::Temp qw/tempfile/;
use Socialtext::Image;

use_ok 'Socialtext::Upload';

fixtures(qw(db));

my $orig = "$ENV{ST_CURRENT}/nlw/t/attachments/grayscale.png";

small_attachment: {
    my $hub = create_test_hub();
    my $creator = $hub->current_user();
    open my $fh, '<', $orig or die "$orig\: $!";
    my $small = $hub->attachments->create(
        filename => $orig,
        fh => $fh,
        creator => $creator,
    );

    my ($large_fh, $large_filename) = tempfile(SUFFIX => '.png');
    Socialtext::Image::resize(
        filename => $orig, to_filename => $large_filename,
        new_width => 1280, new_height => 1024,
    );

    my $large = $hub->attachments->create(
        filename => $large_filename,
        fh => $large_fh,
        creator => $creator,
    );

    my @versions = (
        # $small is 300x150
        [ $small, 'original','',              "300x150x1" ],
        [ $small, 'scaled',  'thumb-600x0',   "300x150x1" ],
        [ $small, 'small',   'resize-100x0',  "100x50x1"  ],
        [ $small, 'medium',  'resize-300x0',  "300x150x1" ],
        [ $small, 'large',   'resize-600x0',  "600x300x1" ],
        [ $small, '800',     'resize-800x0',  "800x400x1" ],
        [ $small, '800x100', 'resize-800x100',"200x100x1" ],
        [ $small, '100x800', 'resize-100x800',"100x50x1"  ],

        # $large is 1280x640
        [ $large, 'original','',              "1280x640x1" ],
        [ $large, 'scaled',  'thumb-600x0',   "600x300x1" ],
        [ $large, 'small',   'resize-100x0',  "100x50x1"  ],
        [ $large, 'medium',  'resize-300x0',  "300x150x1" ],
        [ $large, 'large',   'resize-600x0',  "600x300x1" ],
        [ $large, '800',     'resize-800x0',  "800x400x1" ],
        [ $large, '800x100', 'resize-800x100',"200x100x1" ],
        [ $large, '100x800', 'resize-100x800',"100x50x1"  ],
    );

    for my $v (@versions) {
        my ($attachment, $name, $flavor, $dims) = @$v;
        my $uri = $attachment->prepare_to_serve( $name );

        my $filename = $attachment->upload->disk_filename;
        if ($flavor) {
            $filename .= ".$flavor";
        }
        else {
            $flavor = "original";
        }

        ok -f $filename, "$flavor exists";

        my @actual = Socialtext::Image::get_dimensions($filename);
        is join('x', @actual), $dims, "$flavor dimensions";
    }
}

done_testing;
