#!perl
# @COPYRIGHT@
use warnings;
use strict;

use Test::Socialtext tests => 33;
use Test::Socialtext::CLIUtils qw/:all/;

fixtures(qw(db));

my $ImpersonatorRole = Socialtext::Role->Impersonator;
my $MemberRole       = Socialtext::Role->Member;

my $acct = create_test_account_bypassing_factory();

SET_PERMISSIONS: {
    my $ws = create_test_workspace(account => $acct);
    my $wsname = $ws->name;
    expect_success(
        call_cli_argv('set-permissions',
                qw( --workspace ), $wsname,
                qw(--permissions public-read-only) ),
        qr/\QThe permissions for the $wsname workspace have been changed to public-read-only.\E/,
        'set-permissions success message'
    );

    Socialtext::Cache->clear();
    $ws = Socialtext::Workspace->new(name => $wsname);
    ok(
        $ws->permissions->role_can(
            role       => Socialtext::Role->Guest(),
            permission => Socialtext::Permission->new( name => 'read' ),
        ),
        'guest has read permission'
    );
    ok(
        !$ws->permissions->role_can(
            role       => Socialtext::Role->Guest(),
            permission => Socialtext::Permission->new( name => 'edit' ),
        ),
        'guest does not have edit permission'
    );

    # Rainy day
    expect_failure(
        call_cli_argv('set-permissions',
                qw( --workspace ), $wsname,
                qw(--permissions monkeys-only) ),
        qr/\QThe 'monkeys-only' permission does not exist.\E/,
        'set-permissions error message'
    );
}

ADD_REMOVE_PERMISSION: {
    my $ws = create_test_workspace(account => $acct);
    my $wsname = $ws->name;
    expect_success(
        call_cli_argv('add-permission',
                qw( --workspace ), $wsname,
                qw(--permission edit --role guest)),
        qr/\QThe edit permission has been granted to the guest role in the $wsname workspace.\E/,
        'add-permission success message'
    );

    Socialtext::Cache->clear();
    $ws = Socialtext::Workspace->new(name => $wsname);
    ok(
        $ws->permissions->role_can(
            role       => Socialtext::Role->Guest(),
            permission => Socialtext::Permission->new( name => 'edit' ),
        ),
        'guest has edit permission'
    );

    expect_success(
        call_cli_argv('remove-permission',
                qw( --workspace ), $wsname,
                qw(--permission edit --role guest)),
        qr/\QThe edit permission has been revoked from the guest role in the $wsname workspace.\E/,
        'remove-permission success message'
    );

    Socialtext::Cache->clear();
    $ws = Socialtext::Workspace->new(name => $wsname);
    ok(
        !$ws->permissions->role_can(
            role       => Socialtext::Role->Guest(),
            permission => Socialtext::Permission->new( name => 'edit' ),
        ),
        'guest does not have edit permission'
    );
}

SHOW_ACLS: {
    my $ws = create_test_workspace(account => $acct);
    my $wsname = $ws->name;
    expect_success(
        call_cli_argv('set-permissions',
                qw( --workspace ), $wsname,
                qw(--permissions public-read-only) ),
        qr/\QThe permissions for the $wsname workspace have been changed to public-read-only.\E/,
        'set-permissions success message'
    );

    expect_success(
        call_cli_argv(
            qw(show-acls --workspace ),$ws->name),
        qr/\Qpermission set name: public-read-only\E
           .+
           \|\s+admin_workspace\s+\|\s+\|\s+\|\s+\|\s+\|\s+X\s+\|\s+\|\s+
           \|\s+attachments\s+\|\s+\|\s+\|\s+\|\s+X\s+\|\s+X\s+\|\s+X\s+\|\s+
           .+
           \|\s+read\s+\|\s+X\s+\|\s+X\s+\|\s+\|\s+X\s+\|\s+X\s+\|\s+X\s+\|\s+
          /xs,
        'show-acls'
    );
}

WORKSPACE_IMPERSONATOR: {
    my $ws = create_test_workspace(account => $acct);
    my $wsname = $ws->name;
    
    expect_success(
        call_cli_argv(
            qw(show-impersonators --workspace ),$wsname),
        qr//s,
        'show-impersonators has correct list'
    );
}

add_user_account_impersonator: {
    my $account = create_test_account_bypassing_factory();
    my $user    = create_test_user();

    my $user_name = $user->username;
    my $acct_name = $account->name;

    expect_success(
        call_cli_argv(
            'add-account-impersonator',
            '--username' => $user_name,
            '--account'  => $acct_name,
        ),
        qr/$user_name now has the role of 'impersonator' in the $acct_name Account/,
        'User added as Account Impersonator',
    );

    ok $account->user_has_role(user => $user, role => $ImpersonatorRole),
        '... and User has Impersonator role in Account';
}

remove_user_account_impersonator: {
    my $account = create_test_account_bypassing_factory();
    my $user    = create_test_user();

    my $user_name    = $user->username;
    my $display_name = $user->display_name;
    my $acct_name    = $account->name;

    $account->add_user(user => $user, role => $ImpersonatorRole);
    ok $account->user_has_role(user => $user, role => $ImpersonatorRole),
        'User starts off as an Impersonator in the Account';

    expect_success(
        call_cli_argv(
            'remove-account-impersonator',
            '--username' => $user_name,
            '--account'  => $acct_name,
        ),
        qr/$display_name no longer has the role of 'impersonator' in the $acct_name Account/,
        'User removed as Account Impersonator',
    );

    ok $account->user_has_role(user => $user, role => $MemberRole),
        '... and User was left with Member Role in Account';
}

add_group_account_impersonator: {
    my $account = create_test_account_bypassing_factory();
    my $group   = create_test_group();

    my $group_id     = $group->group_id;
    my $display_name = $group->display_name;
    my $acct_name    = $account->name;

    expect_success(
        call_cli_argv(
            'add-account-impersonator',
            '--group'   => $group_id,
            '--account' => $acct_name,
        ),
        qr/$display_name now has the role of 'impersonator' in the $acct_name Account/,
        'Group added as Account Impersonator',
    );

    ok $account->group_has_role(group => $group, role => $ImpersonatorRole),
        '... and Group has Impersonator role in Account';
}

remove_group_account_impersonator: {
    my $account = create_test_account_bypassing_factory();
    my $group   = create_test_group();

    my $group_id     = $group->group_id;
    my $display_name = $group->display_name;
    my $acct_name    = $account->name;

    $account->add_group(group => $group, role => $ImpersonatorRole);
    ok $account->group_has_role(group => $group, role => $ImpersonatorRole),
        'Group starts off as an Impersonator in the Account';

    expect_success(
        call_cli_argv(
            'remove-account-impersonator',
            '--group'   => $group_id,
            '--account' => $acct_name,
        ),
        qr/$display_name no longer has the role of 'impersonator' in the $acct_name Account/,
        'Group removed as Account Impersonator',
    );

    ok $account->group_has_role(group => $group, role => $MemberRole),
        '... and Group was left with Member Role in Account';
}


pass 'done';
