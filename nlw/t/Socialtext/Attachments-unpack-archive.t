#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 3;
fixtures(qw(db));

use ok 'Socialtext::Attachments';
use ok 'Socialtext::Attachment';

# These tests are primarily to test the way Socialtext::Attachments handles
# archives. See t/archive.t for more extensive tests of how we handle
# various types of archive files.

my $hub = create_test_hub(); # implicitly creates an anonymous workspace

my $page = $hub->pages()->new_from_name('dummy page');
$hub->pages()->current($page);

my $zip = 't/attachments/flat-bundle.zip';
open my $fh, '<', $zip
    or die "Cannot read $zip: $!";

my ($attachment) = $hub->attachments->create(
    page_id  => $page->id,
    fh       => $fh,
    filename => 'PHAT Bundle.zip',
    creator  => $hub->current_user(),
);
$attachment->extract;
$attachment->delete(user => $hub->current_user);

is_deeply(
    [ sort map { $_->filename } @{ $hub->attachments()->all() } ],
    [ qw( html-page-wafl.html index-test.doc socialtext-logo-30.gif ) ],
    "Check that all attachments flat-bundle.zip were unpacked and attached",
);

$page->load;
my $content = $page->content;
ok $content =~ /\Q{file: html-page-wafl.html}/, "has wafl for html file";
ok $content =~ /\Q{file: index-test.doc}/, "has wafl for doc file";
ok $content =~ /\Q{image: socialtext-logo-30.gif}/, "has wafl for doc file";
