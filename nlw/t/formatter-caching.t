#!perl
# @COPYRIGHT@
use strict;
use warnings;

system("rm -rf t/tmp");
use Test::Socialtext tests => 1;
fixtures('admin', 'foobar_no_pages');

my $hub = new_hub('admin');

my $admin = Socialtext::Workspace->new(name => 'admin') or die;
my $foobar = Socialtext::Workspace->new(name => 'foobar') or die;
my $user1 = create_test_user() or die;
my $user2 = create_test_user() or die;

$admin->add_user(user => $user1);
$admin->add_user(user => $user2);
$foobar->add_user(user => $user1);

$hub->current_workspace($admin);
$hub->current_user($user1);

{
    my $page = $hub->pages->new_from_name('Cache me');
    my $text = 'A page with a [wiki link] and a {link: foobar [other link]}';
    $page->content($text);
    $page->store( user => $hub->current_user );
    
    my $html = $page->to_html;

    $hub->current_user($user2);
    $page->to_html;
}
