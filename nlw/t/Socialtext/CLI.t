#!perl
# @COPYRIGHT@
use warnings;
use strict;
use Test::Socialtext tests => 324;
use File::Path qw(rmtree);
use Socialtext::Account;
use Socialtext::SQL qw/sql_execute/;
use Sys::Hostname;
use Cwd;

BEGIN { use_ok 'Socialtext::CLI' }
use Test::Socialtext::CLIUtils qw/expect_failure expect_success/;

fixtures('workspaces_with_extra_pages', 'destructive');

our $NEW_WORKSPACE = 'new-ws-' . $<;
our $NEW_WORKSPACE2 = 'new-ws2-'. $<;
our $NEW_AU_WORKSPACE = 'new-auws-'. $<;

ARGV_PROCESSING: {
    expect_failure(
        sub {
            Socialtext::CLI->new( argv => [qw( --username nomatch )] )
                ->_require_user();
        },
        qr/\QNo user with the username "nomatch" could be found.\E/,
        'invalid username'
    );

    expect_failure(
        sub {
            Socialtext::CLI->new( argv => [qw( --email nomatch )] )
                ->_require_user();
        },
        qr/\QNo user with the email address "nomatch" could be found.\E/,
        'invalid email address'
    );

    expect_failure(
        sub {
            Socialtext::CLI->new( argv => [qw( --workspace nomatch )] )
                ->_require_workspace();
        },
        qr/\QNo workspace named "nomatch" could be found.\E/,
        'invalid workspace name'
    );

    my ( $hub, $main )
        = Socialtext::CLI->new( argv => [qw( --workspace admin )] )
        ->_require_hub();
    can_ok( $hub,  'main' );
    can_ok( $main, 'hub' );

    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --workspace admin --tag nomatch )] )
                ->_require_tags($hub);
        },
        qr/\QThere is no tag "nomatch" in the admin workspace.\E/,
        'require tag no match for --tag',
    );

    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --workspace admin --search nomatch )] )
                ->_require_tags($hub);
        },
        qr/\QNo tags matching "nomatch" were found in the admin workspace.\E/,
        'require tag for --search',
    );

    expect_failure(
        sub {
            Socialtext::CLI->new( argv => [qw( --permission foo )] )
                ->_require_permission();
        },
        qr/\QThere is no permission named "foo".\E/,
        'invalid permission name',
    );

    expect_failure(
        sub {
            Socialtext::CLI->new( argv => [qw( --role foo )] )
                ->_require_role();
        },
        qr/\QThere is no role named "foo".\E/,
        'invalid role name',
    );

    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --workspace admin --page does-not-exist )] )
                ->_require_page($hub);
        },
        qr/\QThere is no page with the id "does-not-exist" in the admin workspace.\E/,
        'invalid page name',
    );

    ok( Socialtext::CLI->new( argv => [qw( --bool )] )->_boolean_flag('bool'),
        '_boolean_flag returns true if the flag is present' );

    ok( ! Socialtext::CLI->new( argv => [] )->_boolean_flag('bool'),
        '_boolean_flag returns false if the flag is not present' );
}

MISSING_ARGS: {
    no warnings 'redefine';

    # _help_as_error calls Pod::Usage::pod2usage(), which in turn calls exit
    local *Socialtext::CLI::_help_as_error = \&Socialtext::CLI::_error;

    expect_failure(
        sub { Socialtext::CLI->new()->_require_user(); },
        qr/\QThe command you called () requires a user to be specified.\E/,
        'no username or email'
    );

    expect_failure(
        sub { Socialtext::CLI->new()->_require_workspace(); },
        qr/\QThe command you called () requires a workspace to be specified.\E/,
        'no workspace'
    );

    expect_failure(
        sub {
            Socialtext::CLI->new()->_require_string('something');
        },
        qr/\QThe command you called () requires a something to be specified with the --something option.\E/,
        'no --something'
    );

    expect_failure(
        sub { Socialtext::CLI->new( argv => [] )->_require_permission(); },
        qr/\QThe command you called () requires a permission to be specified.\E/,
        'no --permission'
    );

    expect_failure(
        sub { Socialtext::CLI->new( argv => [] )->_require_role(); },
        qr/\QThe command you called () requires a role to be specified.\E/,
        'no --role'
    );

    expect_failure(
        sub {
            Socialtext::CLI->new( argv => [qw( --workspace admin )] )
                ->_require_page();
        },
        qr/\QThe command you called () requires a page to be specified.\E/,
        'no --page'
    );
}

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


CONFIRM_USER: {
    my $user = Socialtext::User->create(username => 'devnull5@socialtext.com',
                                        email_address => 'devnull5@socialtext.com' );
    ok( $user, 'User created via User->create' );
    ok(
        ! $user->has_valid_password(),
        'check that password is empty'
    );
    $user->set_confirmation_info();

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

GIVE_REMOVE_ADMIN: {
    # We call ST::User->new each time to force the system to re-fetch
    # the data from the DBMS.
    ok(
        !Socialtext::User->new( username => 'test@example.com' )
            ->is_technical_admin,
        'user does not have system admin priv'
    );

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --username test@example.com )] )
                ->give_system_admin();
        },
        qr/test\@example\.com now has system admin access\./,
        'output from give-system-admin'
    );
    ok(
        Socialtext::User->new( username => 'test@example.com' )
            ->is_technical_admin,
        'user does have system admin priv'
    );

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --username test@example.com )] )
                ->remove_system_admin();
        },
        qr/test\@example\.com no longer has system admin access\./,
        'output from give-system-admin'
    );
    ok(
        !Socialtext::User->new( username => 'test@example.com' )
            ->is_technical_admin,
        'user no longer has system admin priv'
    );

    ok(
        !Socialtext::User->new( username => 'test@example.com' )
            ->is_business_admin,
        'user does not have accounts admin priv'
    );

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --username test@example.com )] )
                ->give_accounts_admin();
        },
        qr/test\@example\.com now has accounts admin access\./,
        'output from give-accounts-admin'
    );
    ok(
        Socialtext::User->new( username => 'test@example.com' )
            ->is_business_admin,
        'user does have accounts admin priv'
    );

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --username test@example.com )] )
                ->remove_accounts_admin();
        },
        qr/test\@example\.com no longer has accounts admin access\./,
        'output from give-accounts-admin'
    );
    ok(
        !Socialtext::User->new( username => 'test@example.com' )
            ->is_business_admin,
        'user no longer has accounts admin priv'
    );
}

DEFAULT_ACCOUNT: {
    sql_execute(q{DELETE FROM "System" WHERE field = 'default-account'});
    Socialtext::Account->Clear_Default_Account_Cache();
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [] )
                ->get_default_account();
        },
        qr/The default account is Unknown\./,
        'output from get-default-account',
    );
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --account Socialtext )] )
                ->set_default_account();
        },
        qr/The default account is now Socialtext\./,
        'output from set-default-account',
    );
    Socialtext::Account->Clear_Default_Account_Cache();
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [] )
                ->get_default_account();
        },
        qr/The default account is Socialtext\./,
        'output from get-default-account',
    );
}

ADD_REMOVE_MEMBER: {
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --username test@example.com --workspace foobar )]
            )->add_member();
        },
        qr/test\@example\.com now has the role of 'member' in the foobar Workspace/,
        'success output from add-member'
    );

    my $ws   = Socialtext::Workspace->new( name => 'foobar' );
    my $user = Socialtext::User->new( username  => 'test@example.com' );
    ok( $ws->has_user( $user ), 'user was added to workspace' );

    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --username test@example.com --workspace foobar )]
            )->add_member();
        },
        qr/.+ already has the role of 'member' in the foobar Workspace/,
        'add-member when user is already a workspace member'
    );

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --username test@example.com --workspace foobar )]
            )->remove_member();
        },
        qr/test\@example\.com no longer has the role of 'member' in foobar/,
        'success output from remove-member'
    );

    $user = Socialtext::User->new( username => 'test@example.com' );
    ok( !$ws->has_user( $user ), 'user was removed from workspace' );

    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --username test@example.com --workspace foobar )]
            )->remove_member();
        },
        qr/test\@example\.com is not a member of foobar/,
        'remove-member when user is not a workspace member'
    );
}

ADD_REMOVE_USER_TO_ACCOUNT: {
    my $account = create_test_account_bypassing_factory();
    my $user1   = create_test_user();
    my $user2   = create_test_user( account => $account );
    my $member  = Socialtext::Role->Member();

    ok !$account->has_user( $user1 ), 'user is not in account';
    ok $account->has_user( $user2 ), 'user is in account, their primary';

    # Cannot remove a user from their primary account
    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [ 
                    '--account', $account->name,
                    '--email',   $user2->email_address,
                ]
            )->remove_member(); 
        },
        qr/You cannot remove a user from their primary account/,
        'cannot remove-member from their primary account'
    );


    # Add a user as a member to the account.
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [ 
                    '--account', $account->name,
                    '--email',   $user1->email_address,
                ]
            )->add_member(); 
        },
        qr/.+ is now a member of the .+ Account/,
        'add-member with an --account and --user argument'
    );
    my $role = $account->role_for_user($user1);
    is $role->display_name, $member->display_name,
        '... user is added to account';

    # User already has a role in the account.
    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [ 
                    '--account', $account->name,
                    '--email',   $user1->email_address,
                ]
            )->add_member(); 
        },
        qr/.+ already has the role of 'member' in the \S+ Account/,
        'add-member with an --account and --user fails, user is in account'
    );
    $role = $account->role_for_user($user1);
    is $role->display_name, $member->display_name,
        '... user is still a member account';

    #  Remove the member from the account.
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [ 
                    '--account', $account->name,
                    '--email',   $user1->email_address,
                ]
            )->remove_member(); 
        },
        qr/.+ no longer has the role of 'member' .+/,
        'remove-member with an --account and --user argument'
    );
    ok !$account->has_user( $user1 ), '... user is removed from account';

    # User is already removed
    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [ 
                    '--account', $account->name,
                    '--email',   $user1->email_address,
                ]
            )->remove_member(); 
        },
        qr/.+ is not a member of .+/,
        'remove-member when user is no longer a member of the account'
    );

    # User has another role in the account.
    my $workspace = create_test_workspace( account => $account );
    $workspace->add_user( user => $user1 );
    $account->add_user( user => $user1 );

    #  Remove the user's _direct_ account role, still have an indirect role.
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [ 
                    '--account', $account->name,
                    '--email',   $user1->email_address,
                ]
            )->remove_member(); 
        },
        qr/.+ now has the role of 'member' in .+ due to membership in a group/,
        'remove-member when user has an indirect role, too'
    );
    $role = $account->role_for_user($user1);
    ok $role, 'user still has a role';
    is $role->display_name, $member->display_name,
        '... and it is a member';

    # Cleanup the workspace
    Test::Socialtext::Workspace->delete_recklessly( $workspace );
}

ADD_REMOVE_WS_ADMIN: {
    my $ws   = Socialtext::Workspace->new( name => 'foobar' );
    my $user = Socialtext::User->new( username  => 'test@example.com' );
    # This adds the workspace to the user's selected workspace list.
    $ws->add_user( user => $user );

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --username test@example.com --workspace foobar )]
            )->add_workspace_admin();
        },
        qr/test\@example\.com now has the role of 'admin' in the foobar Workspace/,
        'success output from add-admin'
    );

    my $admin_role = Socialtext::Role->Admin();
    ok(
        $ws->user_has_role( user => $user, role => $admin_role ),
        'user was added to workspace'
    );

    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --username test@example.com --workspace foobar )]
            )->add_workspace_admin();
        },
        qr/.+ already has the role of 'admin' in the foobar Workspace/,
        'add-admin when user is already an admin'
    );

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --username test@example.com --workspace foobar )]
            )->remove_workspace_admin();
        },
        qr/test\@example\.com no longer has the role of 'admin' in the foobar Workspace/,
        'success output from remove-admin'
    );

    $user = Socialtext::User->new( username => 'test@example.com' );
    my $member_role = Socialtext::Role->Member();
    ok(
        $ws->user_has_role( user => $user, role => $member_role ),
        'user is now a workspace member, but not an admin'
    );

    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --username test@example.com --workspace foobar )]
            )->remove_workspace_admin();
        },
        qr/test\@example\.com does not have the role of 'admin' in the .+ Workspace/,
        'remove-admin when user is not an admin'
    );
}

LIST_WORKSPACES: {
    expect_success(
        sub { Socialtext::CLI->new()->list_workspaces(); },
        "admin\nauth-to-edit\nexchange\nfoobar\nhelp-en\npublic\nsale\n",
        'list-workspaces by name'
    );

    expect_success(
        sub { Socialtext::CLI->new( argv => ['--ids'] )->list_workspaces(); },
        qr/\A\d+\n\d+\n\d+\n\d+\n\d+\n\d+\n\d+\n\z/,
        'list-workspaces by id'
    );
}

CHANGE_PASSWORD: {
    my $new_pw = 'valid-password';

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
    ok( $user->password_is_correct($new_pw), 'new password is valid' );

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

DELETE_TAG: {
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --workspace admin --tag Welcome )] )
                ->delete_tag();
        },
        qr/The following tags were deleted from the admin workspace:\s+\* Welcome\s*\z/s,
        'delete one tag successfully',
    );

    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --workspace admin --tag Welcome )] )
                ->delete_tag();
        },
        qr/\QThere is no tag "Welcome" in the admin workspace.\E/,
        'delete non-existent tag',
    );

    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --workspace admin --category Welcome )] )
                ->delete_category();
        },
        qr/There is no tag "Welcome" in the admin workspace\./,
        'delete one tag using --category',
    );

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --workspace foobar --search e )] )
                ->delete_tag();
        },
        qr/The following tags were deleted from the foobar workspace:\s+(\s+\* [\w\s]+[eE][\w\s]+\s+)+\z/s,
        'delete multiple tags successfully',
    );
}

SEARCH_TAGS: {
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --workspace public --search e )] )
                ->search_tags();
        },
        qr/(\s+\* [\w\s]+[eE][\w\s]+\s+)+/,
        'search tag found matches',
    );
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --workspace public --search e )] )
                ->search_categories();
        },
        qr/(\s+\* [\w\s]+[eE][\w\s]+\s+)+/,
        'search tag found matches',
    );
}

DISABLE_EMAIL_NOTIFY: {
    expect_success(
        sub {
            Socialtext::CLI->new( argv =>
                    [qw( --username devnull1@socialtext.com --workspace admin )] )
                ->disable_email_notify();
        },
        qr/Email notify has been disabled for devnull1\@socialtext\.com in the admin workspace\./,
        'email notify is disabled',
    );
}

CREATE_WORKSPACE: {
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [
                    qw( --account Socialtext --name),
                    $NEW_WORKSPACE,
                    qw( --title ),
                    'New Workspace'
                ]
            )->create_workspace();
        },
        qr/\QA new workspace named "$NEW_WORKSPACE" was created.\E/,
        'create-workspace success message'
    );

    my $ws = Socialtext::Workspace->new( name => $NEW_WORKSPACE );
    ok( $ws, 'workspace was created via create-workspace' );
    is( $ws->title, 'New Workspace', 'check new ws title' );

    expect_failure(
        sub {
            Socialtext::CLI->new( argv =>
                    [ '--name', $NEW_WORKSPACE, '--title', 'New Workspace' ] )
                ->create_workspace();
        },
        qr/\QThe workspace name you provided, "$NEW_WORKSPACE", is already in use.\E/,
        'create-workspace failed with dupe name'
    );

    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [
                    qw( --account NoSuchThing --name $NEW_WORKSPACE2 --title ),
                    'New Workspace'
                ]
            )->create_workspace();
        },
        qr/\QThere is no account named "NoSuchThing".\E/,
        'create-workspace failed with invalid account name'
    );

    # Test --clone-pages-from.  Real tests for this feature are in
    # t/wikitests/rest/workspace-create.wiki
    # To know if it worked, we'll delete a page from the <from> workspace
    # and make sure it doesn't exist on the new workspace.
    my $from_ws = "$NEW_WORKSPACE-from";
    my $to_ws = "$NEW_WORKSPACE-to";
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => ['--workspace', $NEW_WORKSPACE, '--target', $from_ws],
            )->clone_workspace();
        },
        qr{The $NEW_WORKSPACE workspace has been cloned to $from_ws},
        'clone-workspace success message',
    );
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [
                    qw( --workspace ) => $from_ws,
                    qw( --page start_here )] )
                ->purge_page();
        },
        qr/\QThe Start here page was purged from the $from_ws workspace.\E/,
        'purge-page success'
    );
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [
                    qw( --account Socialtext --name) => $to_ws,
                    qw( --title ) => 'New Workspace',
                    qw( --clone-pages-from ) => $from_ws,

                ]
            )->create_workspace();
        },
        qr/\QA new workspace named "$to_ws" was created.\E/,
        'create-workspace success message'
    );
    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [
                    qw( --workspace ) => $to_ws,
                    qw( --page start_here )] )
                ->purge_page();
        },
        qr/\QThere is no page with the id "start_here" in the $to_ws workspace.\E/,
        'workspace was created with the correct pages',
    );

    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [
                    qw( --name ) => "$to_ws-2",
                    qw( --title ) => 'New Workspace',
                    qw( --clone-pages-from ) => 'invalid-no-existy',
                ]
            )->create_workspace();
        },
        qr/\QThe workspace name you provided, "invalid-no-existy", does not exist.\E/,
        'create-workspace failed with invalid clone-pages-from workspace'
    );

# Create all-user workspace    
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [
                    qw( --all-users-workspace --account Socialtext --name),
                    $NEW_AU_WORKSPACE,
                    qw( --title ),
                    'New Workspace'
                ]
            )->create_workspace();
        },
        qr/\QA new workspace named "$NEW_AU_WORKSPACE" was created.\E/,
        'create-workspace success message'
    );

    my $auws = Socialtext::Workspace->new( name => $NEW_AU_WORKSPACE );
    ok( $auws->is_all_users_workspace, 'workspace is all-user workspace' );
}

EXPORT_WORKSPACE: {
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => ['--workspace', $NEW_WORKSPACE],
            )->export_workspace();
        },
        qr{The $NEW_WORKSPACE workspace has been exported to /\S+\.},
        'export-workspace success message',
    );

    my $dir = Cwd::abs_path( File::Temp::tempdir( CLEANUP => 1 ) );
    local $ENV{ST_EXPORT_DIR} = $dir;
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [ '--workspace', $NEW_WORKSPACE ],
            )->export_workspace();
        },
        qr{The $NEW_WORKSPACE workspace has been exported to \Q$dir\E/\S+\.},
        'export-workspace success message with ST_EXPORT_DIR set'
    );
    my @files = glob "$dir/*.tar.gz";
    is( scalar @files, 1, "one .tar.gz file in $dir" );
}

CLONE_WORKSPACE: {
    my $new_clone = "monkey-$NEW_WORKSPACE";
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => ['--workspace', $NEW_WORKSPACE, '--target', $new_clone],
            )->clone_workspace();
        },
        qr{The $NEW_WORKSPACE workspace has been cloned to $new_clone},
        'clone-workspace success message',
    );
}

DELETE_SEARCH_INDEX: {
    expect_success(
        sub {
            Socialtext::CLI->new( argv => ['--workspace', $NEW_WORKSPACE] )
                ->delete_search_index();
        },
        qr/\QThe search index for the $NEW_WORKSPACE workspace has been deleted.\E/,
        'delete-search-index success'
    );
}

INDEX_PAGE: {
    expect_success(
        sub {
            Socialtext::CLI->new( argv =>
                    [ '--workspace', $NEW_WORKSPACE, '--page', 'start_here' ]
            )->index_page();
        },
        qr/\QThe Start here page in the $NEW_WORKSPACE workspace has been indexed.\E/,
        'index-page success'
    );

    # REVIEW - how to test that this did something?
}

INDEX_ATTACHMENT: {
    my ( $hub, $main )
        = Socialtext::CLI->new( argv => [qw( --workspace admin )] )
        ->_require_hub();
    my $att = $hub->attachments()->all( page_id => 'formattingtest' )->[0];
    my $filename = $att->filename();

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [
                    qw( --workspace admin --page formattingtest --attachment  ),
                    $att->id()
                ]
            )->index_attachment();
        },
        qr/\QThe $filename attachment in the admin workspace has been indexed.\E/,
        'index-attachment success'
    );

    # REVIEW - how to test that this did something?

    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [
                    qw( --workspace admin --page formattingtest --attachment no-such-thing ),
                ]
            )->index_attachment();
        },
        qr/\QThere is no attachment with the id "no-such-thing" in the admin workspace./,
        'index-attachment fails with bad attachment id'
    );
}

INDEX_PAGE: {
    expect_success(
        sub {
            Socialtext::CLI->new( argv => ['--workspace', $NEW_WORKSPACE] )
                ->index_workspace();
        },
        qr/\QThe $NEW_WORKSPACE workspace is being indexed.\E/,
        'index-page success'
    );

    # REVIEW - how to test that this did something?
}

DELETE_WORKSPACE: {
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => ['--workspace', $NEW_WORKSPACE],
            )->delete_workspace();
        },
        qr{The $NEW_WORKSPACE workspace has been exported to /\S+ and deleted\.},
        'delete-workspace success message',
    );

    Socialtext::Workspace->create(
        name               => $NEW_WORKSPACE,
        title              => 'Test',
        skip_default_pages => 1,
        account_id         => Socialtext::Account->Socialtext()->account_id,
    );
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [ '--workspace', $NEW_WORKSPACE, '--no-export' ],
            )->delete_workspace();
        },
        qr{The $NEW_WORKSPACE workspace has been deleted\.},
        'delete-workspace success message',
    );
}

CREATE_ACCOUNT: {
    expect_success(
        sub {
            Socialtext::CLI->new( argv => [qw( --name FooBar )] )
                ->create_account();
        },
        qr/\QA new account named "FooBar" was created.\E/,
        'create-account success message'
    );

    my $account = Socialtext::Account->new( name => 'FooBar' );
    ok( $account, 'account was created via create-account' );

    expect_failure(
        sub {
            Socialtext::CLI->new( argv => [qw( --name FooBar )] )
                ->create_account();
        },
        qr/\QThe account name you provided, "FooBar", is already in use.\E/,
        'create-account failed with dupe name'
    );
}

SET_PERMISSIONS: {
    expect_success(
        sub {
            Socialtext::CLI->new( argv =>
                    [qw( --workspace admin --permissions public-read-only )] )
                ->set_permissions();
        },
        qr/\QThe permissions for the admin workspace have been changed to public-read-only.\E/,
        'set-permissions success message'
    );

    my $ws = Socialtext::Workspace->new( name => 'admin' );
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
        sub {
            Socialtext::CLI->new( argv =>
                    [qw( --workspace admin --permissions monkeys-only )] )
                ->set_permissions();
        },
        qr/\QThe 'monkeys-only' permission does not exist.\E/,
        'set-permissions error message'
    );
}

ADD_REMOVE_PERMISSION: {
    expect_success(
        sub {
            Socialtext::CLI->new( argv =>
                    [qw( --workspace admin --permission edit --role guest )] )
                ->add_permission();
        },
        qr/\QThe edit permission has been granted to the guest role in the admin workspace.\E/,
        'add-permission success message'
    );

    my $ws = Socialtext::Workspace->new( name => 'admin' );
    ok(
        $ws->permissions->role_can(
            role       => Socialtext::Role->Guest(),
            permission => Socialtext::Permission->new( name => 'edit' ),
        ),
        'guest has edit permission'
    );

    expect_success(
        sub {
            Socialtext::CLI->new( argv =>
                    [qw( --workspace admin --permission edit --role guest )] )
                ->remove_permission();
        },
        qr/\QThe edit permission has been revoked from the guest role in the admin workspace.\E/,
        'remove-permission success message'
    );

    ok(
        !$ws->permissions->role_can(
            role       => Socialtext::Role->Guest(),
            permission => Socialtext::Permission->new( name => 'edit' ),
        ),
        'guest does not have edit permission'
    );
}

SHOW_ACLS: {
    expect_success(
        sub {
            Socialtext::CLI->new( argv => [qw( --workspace help-en )] )
                ->show_acls();
        },
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

PURGE_ATTACHMENT: {
    my ( $hub, $main )
        = Socialtext::CLI->new( argv => [qw( --workspace foobar )] )
        ->_require_hub();
    my $att = $hub->attachments()->all( page_id => 'formattingtest' )->[0];
    my $filename = $att->filename();
    my $att_id = $att->id();

    ok(
        $att->exists(),
        'Attachment exists'
    );

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --workspace foobar --page formattingtest --attachment  ),
                        $att_id
                    ] )->purge_attachment();
        },
        qr/\QThe $filename attachment was purged from FormattingTest page in the foobar workspace.\E/,
        'purge-page success'
    );

    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [
                    qw( --workspace admin --page formattingtest --attachment ),
                    $att_id
                ]
            )->purge_attachment();
        },
        qr/\QThere is no attachment with the id "$att_id" in the admin workspace./,
        'purge-attachment fails with bad attachment id'
    );

    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [
                    qw( --workspace admin --page formattingtest --attachment no-such-thing ),
                ]
            )->purge_attachment();
        },
        qr/\QThere is no attachment with the id "no-such-thing" in the admin workspace./,
        'purge-attachment fails with bad attachment id'
    );

}

PURGE_PAGE: {
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --workspace foobar --page start_here )] )
                ->purge_page();
        },
        qr/\QThe Start here page was purged from the foobar workspace.\E/,
        'purge-page success'
    );
}

VERSION: {
    expect_success(
        sub {
            Socialtext::CLI->new()->version();
        },
        qr/Socialtext v\d+\.\d+\.\d+\.\d+\s+Copyright 2004-20\d\d Socialtext, Inc\./,
        'purge-page success'
    );

}

SEND_WEBLOG_PINGS: {
    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --workspace admin --page start_here )] )
                ->send_weblog_pings();
        },
        qr/\QThe admin workspace has no ping uris.\E/,
        'send-weblog-pings with no ping uris'
    );

    Socialtext::Workspace->new( name => 'admin' )
        ->set_ping_uris( uris => ['http://localhost/'] );

    require Socialtext::WeblogUpdates;
    my @pages;
    no warnings 'once';
    local *Socialtext::WeblogUpdates::send_ping = sub { push @pages, $_[1] };

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --workspace admin --page start_here )] )
                ->send_weblog_pings();
        },
        qr/\QPings were sent for the Start here page.\E/,
        'send-weblog-pings success'
    );
    is( scalar @pages, 1, 'one ping was sent' );
    is( $pages[0]->id, 'start_here', 'ping was sent for start_here page' );
}

SEND_EMAIL_NOTIFICATIONS: {
    Socialtext::Workspace->new( name => 'admin' )
        ->update( email_notify_is_enabled => 1 );

    require Socialtext::EmailNotifyPlugin;
    my @pages;
    no warnings 'once';
    local *Socialtext::JobCreator::send_page_email_notifications
        = sub { push @pages, $_[1] };
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --workspace admin --page start_here )] )
                ->send_email_notifications();
        },
        qr/\QEmail notifications were sent for the Start here page.\E/,
        'send-email-notifications success'
    );
    is( scalar @pages, 1, 'one notification was sent' );
    is(
        $pages[0]->id, 'start_here',
        'notification was sent for start_here page'
    );

    Socialtext::Workspace->new( name => 'admin' )
        ->update( email_notify_is_enabled => 0 );
    @pages= ();

    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --workspace admin --page start_here )] )
                ->send_email_notifications();
        },
        qr/\QEmail notifications are disabled for the admin workspace.\E/,
        'send-email-notifications with email notify disabled'
    );
    is( scalar @pages, 0, 'no notifications were sent' );
}

SEND_WATCHLIST_EMAILS: {
    require Socialtext::WatchlistPlugin;
    my @pages;
    no warnings 'once';
    local *Socialtext::JobCreator::send_page_watchlist_emails
        = sub { push @pages, $_[1] };

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --workspace admin --page start_here )] )
                ->send_watchlist_emails();
        },
        qr/\QWatchlist emails were sent for the Start here page.\E/,
        'send-watchlist-emails success'
    );
    is( scalar @pages, 1, 'one email was sent' );
    is( $pages[0]->id, 'start_here', 'email was sent for start_here page' );
}

SHOW_WORKSPACE_CONFIG: {
    expect_success(
        sub {
            Socialtext::CLI->new( argv => [qw( --workspace admin )] )
                ->show_workspace_config();
        },
        qr/title\s+:\s+Admin Wiki/,
        'show-workspace-config for admin'
    );
}

SET_WORKSPACE_CONFIG: {
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [
                    qw( --workspace admin title NewTitle basic_search_only 1 )
                ]
            )->set_workspace_config();
        },
        qr/\QThe workspace config for admin has been updated.\E/,
        'set-workspace-config success'
    );

    my $ws = Socialtext::Workspace->new( name => 'admin' );
    is( $ws->title(), 'NewTitle', 'title for admin as changed' );
    ok( $ws->basic_search_only(), 'basic_search_only is true for admin' );

    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --workspace admin nosuchkey NewTitle )] )
                ->set_workspace_config();
        },
        qr/\Qnosuchkey is not a valid workspace config key.\E/,
        'set-workspace-config failure with invalid key'
    );

    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --workspace admin name new-name )] )
                ->set_workspace_config();
        },
        qr/\QCannot change name after workspace creation.\E/,
        'set-workspace-config failure trying to set name'
    );
}

SET_PING_URIS: {
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [
                    qw( --workspace admin http://bar.example.com/ http://foo.example.com/ )
                ]
            )->set_ping_uris();
        },
        qr/\QThe ping uris for the admin workspace have been updated.\E/,
        'set-ping-uris success'
    );

    my $ws = Socialtext::Workspace->new( name => 'admin' );
    my @uris = sort $ws->ping_uris();
    is( scalar @uris, 2, 'workspace has two ping uris' );
    is( $uris[0], 'http://bar.example.com/', 'check first ping uri' );
    is( $uris[1], 'http://foo.example.com/', 'check second ping uri' );

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [
                    qw( --workspace admin )
                ]
            )->set_ping_uris();
        },
        qr/\QThe ping uris for the admin workspace have been updated.\E/,
        'set-ping-uris success'
    );

    $ws = Socialtext::Workspace->new( name => 'admin' );
    @uris = sort $ws->ping_uris();
    is( scalar @uris, 0, 'workspace has no ping uris' );
}

SET_COMMENT_FORM_CUSTOM_FIELDS: {
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [
                    qw( --workspace admin FieldA FieldB )
                ]
            )->set_comment_form_custom_fields();
        },
        qr/\QThe custom comment form fields for the admin workspace have been updated.\E/,
        'set-comment-form-custom-fields success'
    );

    my $ws = Socialtext::Workspace->new( name => 'admin' );
    my @fields = sort $ws->comment_form_custom_fields();
    is( scalar @fields, 2, 'workspace has two fields' );
    is( $fields[0], 'FieldA', 'check first field' );
    is( $fields[1], 'FieldB', 'check second field' );

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [
                    qw( --workspace admin )
                ]
            )->set_comment_form_custom_fields();
        },
        qr/\QThe custom comment form fields for the admin workspace have been updated.\E/,
        'set-comment-form-custom-fields success'
    );

    $ws = Socialtext::Workspace->new( name => 'admin' );
    @fields = sort $ws->comment_form_custom_fields();
    is( scalar @fields, 0, 'workspace has no fields' );
}

# search set tests
CREATE_SEARCH_SET: {
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [
                '--name', 'bozo', '--username',
                'devnull1@socialtext.com'
                ]
            )->create_search_set();
        },
        qr/A search set named 'bozo' was created for user devnull1\@socialtext\.com\./,
        'create-search-set success'
    );
}

ADD_REMOVE_WORKSPACE_TO_SEARCH_SET: {
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [
                '--name', 'bozo', '--username',
                'devnull1@socialtext.com', '--workspace',
                'admin'
                ]
            )->add_workspace_to_search_set();
        },
        qr/'admin' was added to search set 'bozo' for user devnull1\@socialtext\.com\./,
        'add-workspace-to-search-set success'
    );
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [
                '--name', 'bozo', '--username',
                'devnull1@socialtext.com', '--workspace',
                'admin'
                ]
            )->remove_workspace_from_search_set();
        },
        qr/'admin' was removed from search set 'bozo' for user devnull1\@socialtext\.com\./,
        'remove-workspace-from-search-set success'
    );
}

DELETE_SEARCH_SET: {
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [
                '--name', 'bozo', '--username',
                'devnull1@socialtext.com'
                ]
            )->delete_search_set();
        },
        qr/The search set named 'bozo' was deleted for user devnull1\@socialtext\.com\./,
        'delete-search-set success'
    );
}

SET_LOGO_FROM_FILE: {
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [
                    '--workspace', 'admin', '--file',
                    't/attachments/sit#start.png'
                ]
            )->set_logo_from_file();
        },
        qr/The logo file was imported as the new logo for the admin workspace./,
        'set-logo-from-file success'
    );
    my $ws = Socialtext::Workspace->new( name => 'admin' );
    my $logo = $ws->logo_filename();
    like( $logo, qr/\.png$/, 'logo filename is a png' );
}

MASS_COPY_PAGES: {
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [
                    qw( --workspace admin --target foobar )
                ]
            )->mass_copy_pages();
        },
        qr/\QAll of the pages in the admin workspace have been copied to the foobar workspace.\E/,
        'mass-copy-pages success'
    );

    my ( $hub, $main )
        = Socialtext::CLI->new( argv => [qw( --workspace foobar )] )
        ->_require_hub();
    ok( $hub->pages()->new_page('admin_wiki')->exists(),
        '"Admin Wiki" page exists in foobar after mass copy' );

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [
                    qw( --workspace admin --target public --prefix Prefix: )
                ]
            )->mass_copy_pages();
        },
        qr/\QAll of the pages in the admin workspace have been copied to the public workspace,\E
           \Q prefixed with "Prefix:".\E/x,
        'mass-copy-pages success'
    );

    ( $hub, $main )
        = Socialtext::CLI->new( argv => [qw( --workspace public )] )
        ->_require_hub();
    ok( $hub->pages()->new_page('prefix_admin_wiki')->exists(),
        '"Prefix:Admin Wiki" page exists in foobar after mass copy' );
}

ADD_USERS_FROM: {
    my $new_ws = Socialtext::Workspace->create(
        name               => $NEW_WORKSPACE,
        title              => 'Test',
        skip_default_pages => 1,
        account_id         => Socialtext::Account->Socialtext()->account_id,
    );

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [ '--workspace', 'foobar', '--target', $NEW_WORKSPACE ] )
                ->add_users_from();
        },
        qr/\QThe following users from the foobar workspace were added to the $NEW_WORKSPACE workspace:\E\s+
           \Q- devnull1\E\@\Qsocialtext.com\E\s+
           \Q- devnull2\E\@\Qsocialtext.com\E\s+
           \Q- devnull\E\@\Qurth.org\E/xs,
        'copy-users-from success'
    );

    my $devnull2
        = Socialtext::User->new( username => 'devnull2@socialtext.com' );
    ok(
        $new_ws->has_user( $devnull2 ),
        "devnull2\@socialtext.com is a member of $NEW_WORKSPACE"
    );

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [ '--workspace', 'foobar', '--target', $NEW_WORKSPACE ] )
                ->add_users_from();
        },
        qr/\QThere were no users in the foobar workspace not already in the $NEW_WORKSPACE workspace./,
        'copy-users-from success - no users actually copied'
    );
}

UPDATE_PAGE: {
    expect_success(
        sub {
            my $content = <<'EOF';
This is a new page.

Like, totally new. Wow!
EOF

            local *STDIN;
            open STDIN, '<', \$content;

            Socialtext::CLI->new(
                argv => [
                    qw( --workspace admin --username devnull1@socialtext.com --page ),
                    'Totally New'
                ]
            )->update_page();
        },
        qr/\QThe "Totally New" page has been created./,
        'update-page success'
    );

    my ( $hub, $main )
        = Socialtext::CLI->new( argv => [qw( --workspace admin )] )
        ->_require_hub();

    my $page = $hub->pages()->new_from_name('Totally New');
    $page->load();

    ok( $page->exists(), '"Totally New" page exists after update-page' );
    like( $page->content(), qr/Like, totally new/,
          'new page has expected content' );
    is( $page->last_edited_by()->username(), 'devnull1@socialtext.com',
        'page was last edited by devnull1@socialtext.com' );

    expect_failure(
        sub {
            my $content = '';

            local *STDIN;
            open STDIN, '<', \$content;

            Socialtext::CLI->new(
                argv => [
                    qw( --workspace admin --username devnull1@socialtext.com --page ),
                    'Totally New2'
                ]
            )->update_page();
        },
        qr/\Qupdate-page requires that you provide page content on stdin./,
        'update-page fails with no content'
    );
}

INVITE_USER_userexists: {
    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [ '--workspace', 'foobar', '--from', 'test@socialtext.com', '--email', 'devnull1@socialtext.com' ]
            )->invite_user();
        },
        qr/The email address you provided, "devnull1\@socialtext.com", is already a member of the "foobar" workspace\./,
        'Checks to make sure the user does not already exist'
    );
}

INVITE_USER_invalidworkspace: {
    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [ '--workspace', 'DOESNOTEXIST', '--from', 'test@socialtext.com', '--email', 'test1@socialtext.com' ]
            )->invite_user();
        },
        qr/No workspace named/,
        'Checks to make sure the workspace exists'
    );
}

INVITE_USER_noworkspace: {
    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [ '--from', 'test@socialtext.com', '--email', 'test@socialtext.com' ]
            )->invite_user();
        },
        qr/You must specify a workspace/,
        'Checks to make sure a workspace is specified'
    );
}

INVITE_USER_nofrom: {
    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [ '--workspace', 'foobar', '--email', 'test@socialtext.com' ]
            )->invite_user();
        },
        qr/You must specify an inviter email address/,
        'Checks to make sure an inviter email address is specified'
    );
}

INVITE_USER_noemail: {
    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => [ '--workspace', 'foobar', '--from', 'test@socialtext.com' ]
            )->invite_user();
        },
        qr/You must specify an invitee email address/,
        'Checks to make sure an invitee email addres is specified'
    );
}

# Keep this as the last test since it renames a workspace
RENAME_WORKSPACE: {
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [ '--workspace', 'admin', '--name', 'new-admin' ] )
                ->rename_workspace();
        },
        qr/\QThe admin workspace has been renamed to new-admin./,
        'set-logo-from-file success'
    );
    ok(
        Socialtext::Workspace->new( name => 'new-admin' ),
        'new-admin workspace exists'
    );
}

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

GET_SET_USER_ACCOUNT: {
    my $output = '';
    sql_execute(q{DELETE FROM "System" WHERE field = 'default-account'});
    Socialtext::Account->Clear_Default_Account_Cache();
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [qw( --email account@example.com --password foobar )] )
                ->create_user();
        },
        qr/\QA new user with the username "account\E\@\Qexample.com" was created.\E/,
        'create-user success message'
    );
    expect_success(
        sub {
            $output = Socialtext::CLI->new(
                argv => [
                    qw( --username account@example.com )
                ]
            )->get_user_account();
        },
        qr/Primary account for "account\@example\.com" is Unknown/,
        'get primary account by username',
    );
    expect_success(
        sub {
            $output = Socialtext::CLI->new(
                argv => [
                    qw( --username account@example.com --account Socialtext )
                ]
            )->set_user_account();
        },
        qr/User "account\@example\.com" was updated\./,
        'set primary account by username',
    );
    expect_success(
        sub {
            $output = Socialtext::CLI->new(
                argv => [
                    qw( --email account@example.com )
                ]
            )->get_user_account();
        },
        qr/Primary account for "account\@example\.com" is Socialtext/,
        'get primary account by email',
    );
    expect_success(
        sub {
            $output = Socialtext::CLI->new(
                argv => [
                    qw( --email account@example.com --account Socialtext )
                ]
            )->set_user_account();
        },
        qr/User "account\@example\.com" was updated\./,
        'set primary account by email',
    );
    expect_failure(
        sub {
            $output = Socialtext::CLI->new(
                argv => [
                    qw( --email bad_account@example.com --account Socialtext )
                ]
            )->set_user_account();
        },
        qr/No user with the email address "bad_account\@example\.com" could be found/,
        'setting primary account by invalid email',
    );
    expect_failure(
        sub {
            $output = Socialtext::CLI->new(
                argv => [
                    qw( --email account@example.com --account NoAccount )
                ]
            )->set_user_account();
        },
        qr/There is no account named "NoAccount"\./,
        'setting invalid primary account',
    );
}


SHOW_MEMBERS: {
    my $output = '';
    {
        local *STDOUT;
        open STDOUT, '>', '/dev/null';
        eval {
            Socialtext::CLI->new(
                argv => [
                    qw( --email smtest1@socialtext.net --password foobar
                        --first-name Test1 --last-name User )
                ]
            )->create_user();
        };

        eval {
            Socialtext::CLI->new(
                argv => [
                    qw( --email smtest2@socialtext.net --password foobar
                        --first-name Test2 --last-name User )
                ]
            )->create_user();
        };
        eval {
            Socialtext::CLI->new(
                argv => [
                    qw( --email smtest2@socialtext.net --workspace foobar )
                ]
            )->add_member();
        };

        eval {
            Socialtext::CLI->new(
                argv => [
                    qw( --email smtest3@socialtext.net --password foobar
                        --first-name Test3 --last-name User )
                ]
            )->create_user();
        };
        eval {
            Socialtext::CLI->new(
                argv => [
                    qw( --email smtest3@socialtext.net --workspace foobar )
                ]
            )->add_member();
        };
    }

    expect_success(
        sub {
            $output = Socialtext::CLI->new(
                argv => [
                    qw( --workspace foobar )
                ]
            )->show_members();
        },
        qr/^(?!.*smtest1).*smtest2\@socialtext.net \| Test2 \| User \|.*smtest3\@socialtext.net \| Test3 \| User/s,
        'Show members has correct list'
    );

    expect_success(
        sub {
            $output = Socialtext::CLI->new(
                argv => [
                    qw( --account Unknown )
                ]
            )->show_members();
        },
        qr/\| smtest1\@socialtext.net \| Test1 \| User \|/s,
        'Show members has correct list'
    );
}

SHOW_ADMINS: {
    my $output = '';
    {
        local *STDOUT;
        open STDOUT, '>', '/dev/null';
        eval {
            Socialtext::CLI->new(
                argv => [
                    qw( --email smtest2@socialtext.net --workspace foobar )
                ]
            )->add_workspace_admin();
        };
    }

    expect_success(
        sub {
            $output = Socialtext::CLI->new(
                argv => [
                    qw( --workspace foobar )
                ]
            )->show_admins();
        },
        qr/^(?!.*smtest[1|3]).*smtest2\@socialtext.net \| Test2 \|/s,
        'Show admins has correct list'
    );
}

SHOW_IMPERSONATORS: {
    # At this point, devnull2@socialtext.com is an impersonator in the foobar workspace
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [
                    qw( --workspace foobar )
                ]
            )->show_impersonators();
        },
        qr/Last \|\n\| devnull2\@socialtext.com/s,
        'show-impersonators has correct list'
    );
}

# Dear developer:
#
# Please consider making a new CLI-$feature.t test rather than
# appending to this one. The fixtures required for this test are rather
# heavyweight. You may wish to clone t/Socialtext/CLI-deactivate.t; it's a
# good example.
#
# Sincerely,
# ~stash

pass 'done';
