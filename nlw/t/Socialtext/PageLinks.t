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
    is $links->[0]->id, $page1->id, "... with page id";
    is $links->[0]->content, $page1->content, "... with page content";
}

Back_Links: {
    my $backlinks
        = Socialtext::PageLinks->new(page => $page1, hub => $hub)->backlinks;
    is @$backlinks, 1, "one backlink";
    is $backlinks->[0]->id, $page2->id, "... with page id";
    is $backlinks->[0]->content, $page2->content, "... with page content";
}
