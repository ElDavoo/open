#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Cwd;
use File::Path qw(rmtree);
use File::Spec;
use File::Temp qw(tempdir);
use Test::Socialtext tests => 12;
use Socialtext::CLI;
use Socialtext::SQL qw(:exec);
use Test::Socialtext::CLIUtils qw(expect_success expect_failure);

# Fixtures: db
fixtures(qw( db ));

# Tests for `st-admin set-plugin-pref`

Clear_all_prefs: {
    sql_execute('DELETE FROM plugin_pref');
}

Set_pref: {
    expect_success(
        sub {
            Socialtext::CLI->new( argv => [qw(--plugin test key value)] )
                ->set_plugin_pref();
        },
        qr/Preferences for the test plugin have been updated./,
        'set-plugin-pref',
    );
}

Get_prefs: {
    expect_success(
        sub {
            Socialtext::CLI->new( argv => [qw(--plugin test)])
                ->show_plugin_prefs();
        },
        qr/Preferences for the test plugin:.+key\s=>\svalue/s,
            'show-plugin-prefs',
    );
}

Set_another_pref: {
    expect_success(
        sub {
            Socialtext::CLI->new( argv => [qw(--plugin test ape monkey)] )
                ->set_plugin_pref();
        },
        qr/Preferences for the test plugin have been updated./,
        'set-plugin-pref',
    );
}

Get_prefs: {
    expect_success(
        sub {
            Socialtext::CLI->new( argv => [qw(--plugin test)])
                ->show_plugin_prefs();
        },
        qr/Preferences for the test plugin:.+ape => monkey.+key => value/s,
            'show-plugin-prefs',
    );
}

Clear_prefs: {
    expect_success(
        sub {
            Socialtext::CLI->new( argv => [qw(--plugin test)] )
                ->clear_plugin_prefs();
        },
        qr/Preferences for the test plugin have been cleared./,
        'clear-plugin-prefs',
    );

    expect_success(
        sub {
            Socialtext::CLI->new( argv => [qw(--plugin test)])
                ->show_plugin_prefs();
        },
        qr/No preferences set for the test plugin./,
            'show-plugin-prefs',
    );
}

exit;

# bad plugin
