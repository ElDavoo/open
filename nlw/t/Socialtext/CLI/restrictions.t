#!perl

use strict;
use warnings;
use Test::Socialtext tests => 11;
use Socialtext::CLI;
use Test::Socialtext::CLIUtils qw(expect_success expect_failure);

fixtures(qw( db ));


CONFIRM_USER: {
    my $user = Socialtext::User->create(
        username      => 'devnull5@socialtext.com',
        email_address => 'devnull5@socialtext.com',
    );
    ok $user, 'User created via User->create';
    ok !$user->has_valid_password(), 'check that password is empty';
    $user->create_email_confirmation();

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --email devnull5@socialtext.com --password foobar )] )
                ->confirm_user();
            },
            qr/\Qdevnull5\E\@\Qsocialtext.com has been confirmed with password foobar\E/,
            'confirm-user success message'
    );

    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --email devnull5@socialtext.com --password foobar )] )
                ->confirm_user();
        },
        qr/\Qdevnull5\E\@\Qsocialtext.com has already been confirmed\E/,
        'confirm-user failed with already confirmed user'
    );
}

CHANGE_PASSWORD: {
    my $new_pw = 'valid-password';
    my $user = Socialtext::User->create(
        username      => 'test@example.com',
        email_address => 'test@example.com',
    );

    expect_success(
        sub {
            Socialtext::CLI->new( argv =>
                    [ qw( --username test@example.com --password ), $new_pw ]
            )->change_password();
        },
        qr/The password for test\@example\.com has been changed\./,
        'change password successfully',
    );

    my $user = Socialtext::User->new( username => 'test@example.com' );
    ok $user->password_is_correct($new_pw), 'new password is valid';

    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --username test@example.com --password bad )] )
                ->change_password();
        },
        qr/\QPasswords must be at least 6 characters long.\E/,
        'password is too short',
    );
}
