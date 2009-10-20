#!/usr/bin/perl
use strict;
use warnings;

use Test::More qw(no_plan);
use Test::Socialtext;

fixtures('db');
use_ok 'Socialtext::PageLinks';

my $hub = create_test_hub;

# SETUP:
my $page1 = Socialtext::Page->new( hub => $hub )->create(
    title      => 'Some page',
    content    => 'Some content',
    date       => DateTime->new( year => 2000, month => 2, day => 1 ),
    creator    => $hub->current_user,
);
my $page2 = Socialtext::Page->new( hub => $hub )->create(
    title      => 'Some other page',
    content    => 'a link to [Some page]',
    date       => DateTime->new( year => 2000, month => 2, day => 1 ),
    creator    => $hub->current_user,
);

is $page1->content, "Some content\n", "setup page1 properly";

Forward_links: {
    my $links = Socialtext::PageLinks->new(page => $page2, hub => $hub)->links;
    is @$links, 1, "one forward link";
    is $links->[0]->id, $page1->id, "forward link page id";
    is $links->[0]->content, $page1->content, "forward link page content";
}
