#!perl

use strict;
use warnings;

use Test::Socialtext tests => 8;
use Socialtext::CLI;
use Test::Socialtext::CLIUtils qw(:all);
use Test::Socialtext::User;

fixtures(qw( db ));

SET_USER_NAMES: {
    {
        local *STDOUT;
        open STDOUT, '>', '/dev/null';
        eval {
            Socialtext::CLI->new(
                argv => [
                    qw( --email setnames@example.com --password foobar
                        --first-name John --last-name Doe )
                ]
            )->create_user();
        };
    }

    {
        local *STDOUT;
        open STDOUT, '>', '/dev/null';
        eval {
            Socialtext::CLI->new(
                argv => [
                    qw( --email setnames@example.com --first-name Jane --last-name Smith )
                ]
            )->set_user_names();
        };
        warn $@ if $@;
    }

    my $user = Socialtext::User->new( username => 'setnames@example.com' );
    is( $user->first_name(), 'Jane', 'First name updated' );
    is( $user->last_name(),  'Smith',  'Last name updated' );
}

SET_USER_NAMES_no_user: {

    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [
                    qw( --email noususj@example.com --first-name Jane --last-name Smith )
                ]
            )->set_user_names();
        },
        qr/No user with the email address "noususj\@example\.com" could be found\./,
        'Admin warned about missing user'
    );
}

SET_USER_NAMES_firstnameonly: {
    {
        local *STDOUT;
        open STDOUT, '>', '/dev/null';
        eval {
            Socialtext::CLI->new(
                argv => [
                    qw( --email firstnameonly@example.com --password foobar
                        --first-name John --last-name Doe )
                ]
            )->create_user();
        };
    }

    {
        local *STDOUT;
        open STDOUT, '>', '/dev/null';
        eval {
            Socialtext::CLI->new(
                argv => [
                    qw( --email firstnameonly@example.com --first-name Jane )
                ]
            )->set_user_names();
        };
    }

    my $user = Socialtext::User->new( username => 'firstnameonly@example.com' );
    is( $user->first_name(), 'Jane', 'First name updated' );
    is( $user->last_name(),  'Doe',  'Last name still the same' );
}

SET_USER_NAMES_lastnameonly: {
    {
        local *STDOUT;
        open STDOUT, '>', '/dev/null';
        eval {
            Socialtext::CLI->new(
                argv => [
                    qw( --email lastnameonly@example.com --password foobar
                        --first-name John --last-name Doe )
                ]
            )->create_user();
        };
    }

    {
        local *STDOUT;
        open STDOUT, '>', '/dev/null';
        eval {
            Socialtext::CLI->new(
                argv => [
                    qw( --email lastnameonly@example.com --last-name Smith )
                ]
            )->set_user_names();
        };
    }

    my $user = Socialtext::User->new( username => 'lastnameonly@example.com' );
    is( $user->first_name(), 'John', 'First name still the same' );
    is( $user->last_name(),  'Smith',  'Last name changed' );
}


