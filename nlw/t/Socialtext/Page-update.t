#!perl
# @COPYRIGHT@

use warnings;
use strict;
use DateTime;

use ok 'Socialtext::Hub';
use ok 'Socialtext::Page';
use Test::Socialtext tests => 20;
use Socialtext::SQL;
fixtures(qw(empty destructive));

my $hub       = new_hub('empty');
my $page_name = 'update page ' . time();
my $content1  = 'one content';
my $content2  = 'two content';
my $content3  = 'thr content';

# Note: While these test blocks look independent, they're not.
# They must run in order.

UPDATE_AS_CREATE: {
    my $page = _page_object($page_name);

    $page->update(
        content_ref      => \$content1,
        revision         => 0,
        subject          => $page_name,
        user             => $hub->current_user,
    );
    die;

    _validate_page(
        name      => $page_name,
        content   => $content1,
        revision  => 1,
    );
}

UPDATE_PAGE: {
    my $page = _page_object($page_name);

    $page->update(
        content          => $content2,
        revision         => $page->metadata->Revision,
        subject          => $page_name,
        user             => $hub->current_user,
    );

    _validate_page(
        name     => $page_name,
        content  => $content2,
        revision => 2,
    );

}

UPDATE_FROM_REMOTE: {
    my $page = _page_object($page_name);

    $page->update_from_remote(
        content          => $content3,
    );

    _validate_page(
        name     => $page_name,
        content  => $content3,
        revision => 3,
        tags     => [],
    );
}

UPDATE_FROM_REMOTE_AVEC_TAGS: {
    my $page = _page_object($page_name);

    my $singapore = join '', map { chr($_) } 26032, 21152, 22369;
    $page->update_from_remote(
        content          => $content3,
        tags             => ['apple', 'orange', $singapore],
    );

    _validate_page(
        name     => $page_name,
        content  => $content3,
        revision => 4,
        tags     => ['apple', 'orange', $singapore],
    );
}

UPDATE_FROM_REMOTE_PRESERVES_TAGS: {
    my $page = _page_object($page_name);

    my $singapore = join '', map { chr($_) } 26032, 21152, 22369;
    $page->update_from_remote(
        content          => $content3,
    );

    _validate_page(
        name     => $page_name,
        content  => $content3,
        revision => 5,
        tags     => ['apple', 'orange', $singapore],
    );
}

sub _page_object {
    my $name = shift;
    return Socialtext::Page->new(
        hub => $hub,
        id  => Socialtext::String::title_to_id($name),
    );
}

sub _validate_page {
    my %p = @_;

    my $page = $hub->pages->new_from_name( $p{name} );

    # XXX name, title, metadata->Subject: How about just one?
    is( $page->title, $p{name}, "page title should be $p{name}" );
    is( $page->content, $p{content} . "\n",
        "page content should be $p{content}" );
    is( $page->metadata->Revision, $p{revision},
        "page revision should $p{revision}" );
    if ($p{tags}) {
        is_deeply($page->metadata->Category, $p{tags}, 'tags are correct');
    }
}
