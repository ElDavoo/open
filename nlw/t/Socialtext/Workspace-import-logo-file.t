#!perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::Socialtext;

BEGIN {
    unless ( eval { require Image::Magick; 1 } ) {
        plan skip_all => 'These tests require Image::Magick to run.';
    }
}

use Digest::MD5 ();

plan tests => 2;
fixtures(qw( db ));

my $hub     = create_test_hub();
my $ws      = $hub->current_workspace();
my $ws_name = $ws->name();

my $image = 't/attachments/socialtext-logo-30.gif';
$ws->set_logo_from_file(
    filename   => $image,
);

# We need to get this sum because the image is different from the
# original when passed through Image::Magick, even if we don't end up
# resizing it.
my $md5 = md5_checksum( $ws->logo_filename() );

my $tarball = $ws->export_to_tarball(dir => 't/tmp');

# Deleting the user is important so that we know that both user and
# workspace data is restored
$ws->delete();

Socialtext::Workspace->ImportFromTarball( tarball => $tarball );

{
    my $hub = new_hub($ws_name, 'system-user');
    my $ws  = $hub->current_workspace;

    ok( $ws->logo_filename(),
        'check that workspace has a local logo file' );

    is( $md5, md5_checksum( $ws->logo_filename() ),
        'md5 checksum for original image and logo after import are the same' );
}

sub md5_checksum {
    my $file = shift;
    open my $fh, '<', $file
        or die "Cannot read $file: $!";

    return Digest::MD5::md5_hex( do { local $/; <$fh> } );
}
