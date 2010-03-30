#!perl
# @COPYRIGHT@

use warnings;
use strict;

use Test::Socialtext tests => 8;
fixtures( 'admin' );

# The point of this test is to test page duplication without ever
# loading the workspaces class

my $admin_hub = new_hub('admin');
my $user = $admin_hub->current_user;
my $pages = $admin_hub->pages;

{
    my $cat = 'Category Delete Test';

    my $page = $pages->new_from_name('Admin');
    $page->content('test content');
    $page->metadata->Category([ @{ $page->metadata->Category }, $cat ]);
    $page->store(user => $user);

    is( ( scalar grep { $_->is_in_category($cat) } $pages->all), 1,
        'There is one page in the "Category Delete Test" category');

    my $categories = $admin_hub->category;
    $categories->delete(tag  => $cat, user => $user);

    is( ( scalar grep { $_->is_in_category($cat) } $pages->all), 0,
        'There are no pages in the "Category Delete Test" category');

    my %cats = map { $_ => 1 } $categories->all;
    ok( !$cats{$cat},
        'Categories object no longer contains reference to deleted tag');
}

{
    my $cat = 'Category Delete Test 2';

    my $page = $pages->new_from_name('Admin');
    $page->content('test content');
    $page->metadata->Category( [ @{$page->metadata->Category}, $cat ] );
    $page->store( user => $user );

    $page = $pages->new_from_name('Conversations');
    $page->content('test content');
    $page->metadata->Category( [ @{$page->metadata->Category}, $cat ] );
    $page->store( user => $user );

    is( ( scalar grep { $_->is_in_category($cat) } $pages->all ), 2,
        'There are two pages in the "Category Delete Test 2" category' );

    my $categories = $admin_hub->category;
    $categories->delete(tag => $cat, user => $user);

    is( ( scalar grep { $_->is_in_category($cat) } $pages->all ), 0,
        'There are no pages in the "Category Delete Test 2" category' );

    my %cats = map { $_ => 1 } $categories->all;
    ok( ! $cats{$cat},
        'Categories object no longer contains reference to "Category Delete Test 2"' );
}

caseless_delete: {
    # Capitalized Tag
    my $page = $pages->new_from_name('Maxwell Banjo');
    $page->content('test content');
    $page->metadata->Category([
        @{$page->metadata->Category}, 'Dog', # capitalized
    ]);
    $page->store( user => $user );

    # lowercase tag
    $page = $pages->new_from_name('Warren Kaczynski');
    $page->content('test content');
    $page->metadata->Category([
        @{$page->metadata->Category}, 'dog',
    ]);
    $page->store( user => $user );

    # should delete 'Dog' and 'dog'.
    my $categories = $admin_hub->category;
    $categories->delete(tag => 'dog', user => $user);

    is( ( scalar grep { $_->is_in_category('Dog') } $pages->all ), 0,
        'There are no pages in the "Dog" category' );

    is( ( scalar grep { $_->is_in_category('dog') } $pages->all ), 0,
        'There are no pages in the "dog" category' );
}
