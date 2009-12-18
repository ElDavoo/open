#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::Socialtext qw/no_plan/;
use Test::Exception;
fixtures(qw(plugin));

my $hub = create_test_hub;
my $user1 = create_test_user();
my $user2 = create_test_user();
my $ws = create_test_workspace(user => $user1);
$hub->current_user($user1);
$hub->current_workspace($ws);
$hub->pages->new_from_name('something');
$hub->pages->new_from_name('page2');

my $plugin = Socialtext::Pluggable::Plugin::Prefsetter->new;
$plugin->hub($hub);

# Get/Set
{
    lives_ok {
        $plugin->set_page_prefs(
            workspace_name => $ws->name,
            page_id        => 'something',
            prefs          => {
                number => 43,
                string => 'hi',
            },
        );
    } "set_page_prefs";

    my $expected = $plugin->get_page_prefs(
        workspace_name => $ws->name,
        page_id        => 'something'
    );
    is_deeply $expected, { number => 43, string => 'hi' },
        'get_page_prefs';
}

# Check perms
{
    $hub->current_user($user2);
    my $returned;
    lives_ok {
        $returned = $plugin->set_page_prefs(
            workspace_name => $ws->name,
            page_id        => 'something',
            prefs          => { number => 32 }
        );
    } "set_user_prefs(number => SCALAR)";

    ok !defined($returned), "Can't set without comment privs";
}

# settings are not user scoped
{
    $hub->current_user($user1);
    $ws->add_user(user => $user2);

    lives_ok {
        $plugin->set_page_prefs(
            workspace_name => $ws->name,
            page_id        => 'something',
            prefs          => {
                number => 38,
                string => undef,
            },
        );
    } "set_user_prefs(number => SCALAR)";

    $hub->current_user($user2);

    my $expected = $plugin->get_page_prefs(
        workspace_name => $ws->name,
        page_id        => 'something'
    );
    is_deeply $expected, { number => 38 },
          "prefs are user scoped";

    $hub->current_user($user1);
#     lives_ok { $plugin->set_page_prefs($ws->name, 'something', number => 38) }
#              "set_user_prefs(number => SCALAR)";
}

# Settings are page scoped
{
    lives_ok {
        $plugin->set_page_prefs(
            workspace_name => $ws->name,
            page_id        => 'something',
            prefs          => {
                number => 1,
                string => 'page something',
            },
        );
    } "set_page_prefs";

    lives_ok {
        $plugin->set_page_prefs(
            workspace_name => $ws->name,
            page_id        => 'page2',
            prefs          => {
                number => 2,
                string => 'page 2',
            },
        );
    } "set_page_prefs";

    my $expected = $plugin->get_page_prefs(
        workspace_name => $ws->name,
        page_id        => 'something',
    );
    is_deeply $expected, { number => 1, string => 'page something' },
        'something prefs are correct';
 
    $expected = $plugin->get_page_prefs(
        workspace_name => $ws->name,
        page_id        => 'page2',
    );
    is_deeply $expected, { number => 2, string => 'page 2' },
        'page2 prefs are correct';
    
}

{
    my $other_plugin = Socialtext::Pluggable::Plugin::Other->new;
    $other_plugin->hub($hub);
    $hub->current_user($user1);

    my $expected = $other_plugin->get_page_prefs(
        workspace_name => $ws->name,
        page_id        => 'something',
    );
    is_deeply $expected, {}, "prefs are plugin scoped";
}

package Socialtext::Pluggable::Plugin::Prefsetter;
use base 'Socialtext::Pluggable::Plugin';
sub scope { 'workspace' }

package Socialtext::Pluggable::Plugin::Other;
use base 'Socialtext::Pluggable::Plugin';
sub scope { 'workspace' }
