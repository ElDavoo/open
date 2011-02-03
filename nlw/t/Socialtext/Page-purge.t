#!perl
# @COPYRIGHT@
use warnings;
use strict;
use Test::Socialtext tests => 2;
fixtures(qw( admin no-ceq-jobs destructive ));
use Socialtext::Jobs;


my $hub = new_hub('admin');
my $page = $hub->pages->new_from_name('Start here');

{
    my @pages = $hub->category->get_pages_for_category('Welcome');
    my $is_in_help = grep { $_->title eq 'Start here' } @pages;
    ok( $is_in_help, '"Start here" is in Welcome category before purge()' );
}

{
    $page->purge();

    my @pages = $hub->category->get_pages_for_category('Welcome');
    my $is_in_help = grep { $_->title eq 'Start here' } @pages;
    ok( !$is_in_help,
        '"Start here" is not in Welcome category before purge()' );
}
