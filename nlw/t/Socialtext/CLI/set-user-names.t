#!perl

use strict;
use warnings;
use Test::Socialtext tests => 20;
use Socialtext::CLI;
use Test::Socialtext::CLIUtils qw(:all);
use Test::Socialtext::User;

fixtures(qw( db ));

###############################################################################
# TEST: Set User names
SET_USER_NAMES: {
    my $guard = Test::Socialtext::User->snapshot();

    expect_success(
        call_cli_argv(
            'create-user',
            '--email'      => 'setnames@example.com',
            '--password'   => 'foobar',
            '--first-name' => 'John',
            '--last-name'  => 'Doe',
        ),
        qr/new user.*created/,
        'created new User',
    );

    expect_success(
        call_cli_argv(
            'set-user-names',
            '--email'      => 'setnames@example.com',
            '--first-name' => 'Jane',
            '--last-name'  => 'Smith',
        ),
        qr/User "[^"]+" was updated/,
        'Names updated for User'
    );

    my $user = Socialtext::User->new( username => 'setnames@example.com' );
    is $user->first_name, 'Jane',  '... first name updated';
    is $user->last_name,  'Smith', '... last name updated';
}

###############################################################################
# TEST: Set User names, when User doesn't exist yet
set_user_names_no_user: {
    my $guard = Test::Socialtext::User->snapshot();

    expect_failure(
        call_cli_argv(
            'set-user-names',
            '--email'      => 'noususj@example.com' ,
            '--first-name' => 'Jane' ,
            '--last-name'  => 'Smith' ,
        ),
        qr/No user with the email address "noususj\@example\.com" could be found\./,
        'Admin warned about missing user'
    );
}

###############################################################################
# TEST: Set only the first name
set_user_names_firstnameonly: {
    my $guard = Test::Socialtext::User->snapshot();

    expect_success(
        call_cli_argv(
            'create-user',
            '--email'      => 'firstnameonly@example.com',
            '--password'   => 'foobar',
            '--first-name' => 'John',
            '--last-name'  => 'Doe',
        ),
        qr/new user.*created/,
        'created new User',
    );

    expect_success(
        call_cli_argv(
            'set-user-names',
            '--email'      => 'firstnameonly@example.com',
            '--first-name' => 'Jane',
        ),
        qr/User "[^"]+" was updated/,
        'First name updated for User'
    );

    my $user = Socialtext::User->new( username => 'firstnameonly@example.com' );
    is $user->first_name, 'Jane', '... first name updated';
    is $user->last_name,  'Doe',  '... last name still the same';
}

###############################################################################
# TEST: Set only the last name
set_user_names_lastnameonly: {
    my $guard = Test::Socialtext::User->snapshot();

    expect_success(
        call_cli_argv(
            'create-user',
            '--email'      => 'lastnameonly@example.com',
            '--password'   => 'foobar',
            '--first-name' => 'John',
            '--last-name'  => 'Doe',
        ),
        qr/new user.*created/,
        'created new User',
    );

    expect_success(
        call_cli_argv(
            'set-user-names',
            '--email'     => 'lastnameonly@example.com',
            '--last-name' => 'Smith',
        ),
        qr/User "[^"]+" was updated/,
        'Last name updated for User'
    );

    my $user = Socialtext::User->new( username => 'lastnameonly@example.com' );
    is $user->first_name, 'John',  '... first name still the same';
    is $user->last_name,  'Smith', '... last name updated';
}
