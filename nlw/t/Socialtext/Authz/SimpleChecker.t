#!/usr/bin/perl
# @COPYRIGHT@

use Test::Socialtext tests => 44;
use Socialtext::Role;
use Socialtext::Permission;

fixtures('db');

use_ok 'Socialtext::Authz::SimpleChecker';

my $ws = create_test_workspace();

my $admin_user  = create_test_user();
my $member_user = create_test_user();
my $guest_user  = create_test_user();

my $admin_role  = Socialtext::Role->Admin();
my $member_role = Socialtext::Role->Member();

my $result;

################################################################################
# Add users to workspace, verify roles.

$ws->add_user( user => $admin_user, role => $admin_role );
$result = $ws->role_for_user( $admin_user, {direct => 1});
is $result->role_id, $admin_role->role_id, 'admin has correct role';

$ws->add_user( user => $member_user, role => $member_role );
$result = $ws->role_for_user( $member_user, {direct => 1});
is $result->role_id, $member_role->role_id, 'member has correct role';

$result = $ws->role_for_user( $guest_user, {direct => 1});
ok !$result, 'guest has no role in workspace';

################################################################################
# Admin, Default setup
admin_user_with_default: {
    diag('Admin user...');

    perms_as_expected($admin_user, {
        read => 1,
        edit => 1,
        attachments => 1,
        comment => 1,
        delete => 1,
        email_in => 1,
        email_out => 1,
        edit_controls => 0,
        admin_workspace => 1,
        request_invite => 0,
        impersonate => 0,
        lock => 1,
        self_join => 0,
    });
}

################################################################################
# Member, Default setup
member_user_with_default: {
    diag('Member user...');

    perms_as_expected($member_user, {
        read => 1,
        edit => 1,
        attachments => 1,
        comment => 1,
        delete => 1,
        email_in => 1,
        email_out => 1,
        edit_controls => 0,
        admin_workspace => 0,
        request_invite => 0,
        impersonate => 0,
        lock => 0,
        self_join => 0,
    });
}

################################################################################
# Guest, Default setup
guest_user_with_default: {
    diag('Guest user...');

    perms_as_expected($guest_user, {
        read => 0,
        edit => 0,
        attachments => 0,
        comment => 0,
        delete => 0,
        email_in => 0,
        email_out => 0,
        edit_controls => 0,
        admin_workspace => 0,
        request_invite => 0,
        impersonate => 0,
        lock => 0,
        self_join => 0,
    });
}

################################################################################
# Allows Page Locking
page_locking: {
    my $hub = Test::Socialtext::new_hub($ws->name, $admin_user->username);
    my $page = $hub->pages->new_page_from_any('test page');
    $page->metadata->update( user => $hub->current_user );

    my $checker = Socialtext::Authz::SimpleChecker->new(
        user      => $hub->current_user,
        workspace => $hub->current_workspace,
    );

    is $checker->can_modify_locked($page), 1,
        'admin could modify a locked page';
}


exit;
################################################################################

sub perms_as_expected {
    my $user     = shift;
    my $expected = shift;

    my $checker = Socialtext::Authz::SimpleChecker->new(
        user => $user,
        workspace => $ws,
    );

    for my $perm ( keys %$expected ) {
        my $result = $checker->check_permission($perm);
        is $result, $expected->{$perm}, "... has expected $perm permission";
    }
}
