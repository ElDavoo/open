#!/usr/bin/env perl
# @COPYRIGHT@

use strict;
use warnings;
use Socialtext::Job::RemoveNonImageScaling;
use File::Find::Rule;
use Socialtext::File::Copy::Recursive qw(dircopy);
use File::Temp qw(tempdir);

use Test::Socialtext tests => 6;

my $job = new Socialtext::Job::RemoveNonImageScaling();

ok $job->_invalid_image('application/appledriveimage'), 'mime type with trailing image text not valid';
ok $job->_invalid_image('applimagecation/appledrive'), 'mime type with image in the middle not valid';
ok !$job->_invalid_image('image/png'), 'mime type starting with image is valid';

my $tmpdir = tempdir(CLEANUP => 1);
dircopy('t/test-data/remove_scaled', $tmpdir);

my $files = $job->_mime_files($tmpdir);
is scalar(@$files), 4, 'Found correct number of mime files';

my @scaled = File::Find::Rule->file()
   ->mindepth(3)
   ->in($tmpdir);
@scaled = grep { /scaled/ } @scaled;
is scalar(@scaled), 2, '2 scaled directories in the test data';

$job->_delete_scaled_dir("$tmpdir/has_bad_attachments/bad_att/bad_att.dmg-mime");

@scaled = File::Find::Rule->file()
   ->mindepth(3)
   ->in($tmpdir);
@scaled = grep { /scaled/ } @scaled;

is scalar(@scaled), 1, 'Scaled directory deleted';
