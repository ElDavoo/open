#!perl

use strict;
use warnings;
use Test::Socialtext tests => 21;
use Socialtext::CLI;
use Test::Socialtext::CLIUtils qw(:all);
use Test::Socialtext::User;

fixtures(qw( db ));

###############################################################################
# TEST: Can confirm User with outstanding e-mail confirmation.
confirm_user: {
    my $guard = Test::Socialtext::User->snapshot;
    my $user  = create_test_user();
    ok $user, 'Created test User';

    $user->create_email_confirmation();
    ok $user->email_confirmation,  '... e-mail confirmation set';
    ok !$user->has_valid_password(), '... password is empty';

    expect_success(
        call_cli_argv(
            'confirm-user',
            '--email'    => $user->email_address,
            '--password' => 'foobar',
        ),
        qr/has been confirmed with password foobar/,
        'confirm-user success message'
    );

    # reload User and check that they were confirmed properly
    $user->reload;
    ok !$user->email_confirmation, '... e-mail confirmation was removed';
    ok $user->has_valid_password(), '... password now valid after confirmation';
}

###############################################################################
# TEST: Cannot confirm a User that has *no* outstanding e-mail confirmation
cannot_confirm_already_confirmed_user: {
    my $guard = Test::Socialtext::User->snapshot;
    my $user  = create_test_user();
    ok $user, 'Created test User';

    ok !$user->email_confirmation, '... has no e-mail confirmation';

    expect_failure(
        call_cli_argv(
            'confirm-user',
            '--email'    => $user->email_address,
            '--password' => 'foobar',
        ),
        qr/has already been confirmed\E/,
        'confirm-user failed with already confirmed user'
    );
}

###############################################################################
# TEST: Change the password for a User.
change_password: {
    my $guard  = Test::Socialtext::User->snapshot;
    my $user   = create_test_user();
    my $new_pw = 'valid-password';

    expect_success(
        call_cli_argv(
            'change-password',
            '--username' => $user->username,
            '--password' => $new_pw,
        ),
        qr/The password for \S+ has been changed\./,
        'change password successfully',
    );

    $user->reload;
    ok $user->password_is_correct($new_pw), 'new password is valid';
}

###############################################################################
# TEST: Changing User's password fails if password is too short.
change_password_too_short: {
    my $guard  = Test::Socialtext::User->snapshot;
    my $user   = create_test_user();

    expect_failure(
        call_cli_argv(
            'change-password',
            '--username' => $user->username,
            '--password' => 'bad',
        ),
        qr/\QPasswords must be at least 6 characters long.\E/,
        'password is too short',
    );
}

###############################################################################
# TEST: Changing User's password removes any "change password" restrictions
change_password_removes_restrictions: {
    my $guard = Test::Socialtext::User->snapshot;
    my $user  = create_test_user();
    ok $user, 'Created test user';

    $user->create_password_change_confirmation();
    ok $user->password_change_confirmation, '... password change set';

    expect_success(
        call_cli_argv(
            'change-password',
            '--username' => $user->username,
            '--password' => 'abc123',
        ),
        qr/The password for \S+ has been changed\./,
        'change password successfully',
    );

    # reload User and check that the restriction is now gone
    $user->reload;
    ok !$user->password_change_confirmation, '... password change cleared';
}
