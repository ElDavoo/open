#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 31;
use Socialtext::CLI;
use Test::Socialtext::CLIUtils qw(expect_failure expect_success);

fixtures(qw( db ));

my $ImpersonatorRole = Socialtext::Role->Impersonator();
my $MemberRole       = Socialtext::Role->Member();

###############################################################################
# TEST: Add User as WS Impersonator when they have *no* role in WS
add_user_as_workspace_impersonator: {
    my $ws   = create_test_workspace();
    my $user = create_test_user();

    my $username = $user->username;
    my $ws_name  = $ws->name;

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => ['--username', $username, '--workspace', $ws_name],
            )->add_workspace_impersonator();
        },
        qr/$username now has the role of 'impersonator' in the $ws_name Workspace/,
        'User added as Impersonator to Workspace',
    );

    ok $ws->user_has_role(user => $user, role => $ImpersonatorRole),
        '... and User has Impersonator Role in WS';
}

###############################################################################
# TEST: Add User as WS Impersonator when they're already a Member of the WS
add_member_user_as_workspace_impersonator: {
    my $ws   = create_test_workspace();
    my $user = create_test_user();

    my $username = $user->username;
    my $ws_name  = $ws->name;

    $ws->add_user(user => $user);
    ok $ws->user_has_role(user => $user, role => $MemberRole),
        'User starts off as a Member of the WS';

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => ['--username', $username, '--workspace', $ws_name],
            )->add_workspace_impersonator();
        },
        qr/$username now has the role of 'impersonator' in the $ws_name Workspace/,
        'User elevated to Impersonator of Workspace',
    );

    ok $ws->user_has_role(user => $user, role => $ImpersonatorRole),
        '... and User has Impersonator Role in WS';
}

###############################################################################
# TEST: Add User as WS Impersonator when they're already an Impersonator of the WS
add_impersonator_user_as_workspace_impersonator: {
    my $ws   = create_test_workspace();
    my $user = create_test_user();

    my $username = $user->username;
    my $ws_name  = $ws->name;

    $ws->add_user(user => $user, role => $ImpersonatorRole);
    ok $ws->user_has_role(user => $user, role => $ImpersonatorRole),
        'User starts off as an Impersonator of the WS';

    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => ['--username', $username, '--workspace', $ws_name],
            )->add_workspace_impersonator();
        },
        qr/already has the role of 'impersonator' in the $ws_name Workspace/,
        'User already has Impersonator Role in Workspace',
    );
}

###############################################################################
# TEST: Remove WS Impersonator from WS
remove_workspace_impersonator: {
    my $ws   = create_test_workspace();
    my $user = create_test_user();

    my $username     = $user->username;
    my $display_name = $user->display_name;
    my $ws_name      = $ws->name;

    $ws->add_user(user => $user, role => $ImpersonatorRole);
    ok $ws->user_has_role(user => $user, role => $ImpersonatorRole),
        'User starts off as an Impersonator of the WS';

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => ['--username', $username, '--workspace', $ws_name],
            )->remove_workspace_impersonator();
        },
        qr/$display_name no longer has the role of 'impersonator' in the $ws_name Workspace/,
        'User removed as Impersonator from Workspace',
    );

    ok $ws->user_has_role(user => $user, role => $MemberRole),
        '... and User was left with Member Role in WS';
}

###############################################################################
# TEST: Remove WS Impersonator from WS when they're only a Member
remove_member_as_workspace_impersonator: {
    my $ws   = create_test_workspace();
    my $user = create_test_user();

    my $username     = $user->username;
    my $display_name = $user->display_name;
    my $ws_name      = $ws->name;

    $ws->add_user(user => $user, role => $MemberRole);
    ok $ws->user_has_role(user => $user, role => $MemberRole),
        'User starts off as an Member of the WS';

    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => ['--username', $username, '--workspace', $ws_name],
            )->remove_workspace_impersonator();
        },
        qr/$display_name does not have the role of 'impersonator' in the $ws_name Workspace/,
        'User was not an Impersonator; cannot remove them as an Impersonator',
    );

    ok $ws->user_has_role(user => $user, role => $MemberRole),
        '... and User still has Member Role in WS';
}

###############################################################################
# TEST: Remove WS Impersonator from WS when they're not in the WS
remove_non_member_as_workspace_impersonator: {
    my $ws   = create_test_workspace();
    my $user = create_test_user();

    my $username     = $user->username;
    my $display_name = $user->display_name;
    my $ws_name      = $ws->name;

    ok !$ws->has_user($user), 'User starts off not being associated with WS';

    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => ['--username', $username, '--workspace', $ws_name],
            )->remove_workspace_impersonator();
        },
        qr/$display_name does not have the role of 'impersonator' in the $ws_name Workspace/,
        'User was not a member of Workspace to begin with',
    );

    ok !$ws->has_user($user), '... User still has no Role in WS';
}

###############################################################################
# TEST: Show list of WS Impersonators
show_workspace_impersonators: {
    my $ws             = create_test_workspace();
    my $impersonator_user     = create_test_user();
    my $member_user    = create_test_user();
    my $unrelated_user = create_test_user();

    my $ws_name            = $ws->name;
    my $impersonator_username     = $impersonator_user->username;
    my $member_username    = $member_user->username;
    my $unrelated_username = $unrelated_user->username;

    $ws->add_user(user => $impersonator_user, role => $ImpersonatorRole);
    ok $ws->user_has_role(user => $impersonator_user, role => $ImpersonatorRole),
        'User starts off as an Impersonator of the WS';

    $ws->add_user(user => $member_user, role => $MemberRole);
    ok $ws->user_has_role(user => $member_user, role => $MemberRole),
        'User starts off as an Member of the WS';

    ok !$ws->has_user($unrelated_user),
        'User has no Role in the WS';

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => ['--workspace', $ws_name],
            )->show_impersonators();
        },
        qr/$impersonator_username/s,
        'Impersonator User is shown as an Impersonator of the WS',
    );

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => ['--workspace', $ws_name],
            )->show_impersonators();
        },
        qr/(?!$member_username)/s,
        'Member User is *not* shown as an Impersonator of the WS',
    );

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => ['--workspace', $ws_name],
            )->show_impersonators();
        },
        qr/(?!$unrelated_username)/s,
        'Unrelated User is *not* shown as an Impersonator of the WS',
    );
}
