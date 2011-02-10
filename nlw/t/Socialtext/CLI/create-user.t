#!perl

use strict;
use warnings;
use Test::Socialtext tests => 21;
use Socialtext::CLI;
use Socialtext::Account;

use Test::Socialtext::CLIUtils qw/expect_failure expect_success/;

fixtures(qw( clean db ));

CREATE_USER: {
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --email test@example.com --password foobar )] )
                ->create_user();
        },
        qr/\QA new user with the username "test\E\@\Qexample.com" was created.\E/,
        'create-user success message'
    );

    my $user = Socialtext::User->new( username => 'test@example.com' );
    ok( $user, 'User was created via create_user' );
    ok(
        $user->password_is_correct('foobar'),
        'check that given password works'
    );

    is(
        $user->email_address(), 'test@example.com',
        'email and username are the same'
    );
    is $user->primary_account->name, Socialtext::Account->Default->name,
        'default primary account set';


    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --email account-test@example.com --password foobar 
                             --account Socialtext
                           )] )
                ->create_user();
        },
        qr/\QA new user with the username "account-test\E\@\Qexample.com" was created.\E/,
        'create-user success message'
    );
    my $user2 = Socialtext::User->new( username => 'account-test@example.com' );
    is $user2->primary_account->name, Socialtext::Account->Socialtext->name,
        'primary account set';

    # User with external private ID
    my $email = Test::Socialtext::create_unique_id() . '@ken.socialtext.net';
    my $external_id = 'abc123';
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => ['--email' => $email,
                         '--password' => 'password',
                         '--external-id' => $external_id,
                ],
            )->create_user();
        },
        qr/A new user with the username "[^"]+" was created./,
        'created user with a private external id',
    );
    $user = Socialtext::User->new(email_address => $email);
    isa_ok $user, 'Socialtext::User', 'got a user';
    is $user->private_external_id, $external_id, '... with external ID';

    # User with conflicting external private ID (ID recycled from above)
    $email = Test::Socialtext::create_unique_id() . '@ken.socialtext.net';
    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => ['--email' => $email,
                         '--password' => 'password',
                         '--external-id' => $external_id,
                ],
            )->create_user();
        },
        qr/The private external id you provided \([^\)]+\) is already in use./,
        'failed to create user with a conflicting external id',
    );

    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --email test@example.com --password foobar )] )
                ->create_user();
        },
        qr/\QThe email address you provided, "test\E\@\Qexample.com", is already in use.\E/,
        'create-user failed with dupe email'
    );

    expect_failure(
        sub {
            Socialtext::CLI->new( argv => [] )->create_user();
        },
        qr/Username is a required field.+Email address is a required field.+password is required/s,
        'create-user failed with no args'
    );

    {
        local *STDOUT;
        open STDOUT, '>', '/dev/null';
        eval {
            Socialtext::CLI->new(
                argv => [
                    qw( --email test2@example.com --password foobar
                        --first-name John --last-name Doe )
                ]
            )->create_user();
        };
    }

    $user = Socialtext::User->new( username => 'test2@example.com' );
    is( $user->first_name(), 'John', 'new user first name' );
    is( $user->last_name(),  'Doe',  'new user last name' );

}


