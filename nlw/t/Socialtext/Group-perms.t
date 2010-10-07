#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::Socialtext tests => 40;
use Test::Socialtext::Account qw/export_account export_and_reimport_account/;
use Test::Exception;
use YAML qw/LoadFile/;

fixtures(qw( db ));

################################################################################
# TEST: update group perms, ws membership controlled by group
update_perms_controlling_ws: {
    my $ws  = create_test_workspace();
    my $grp = create_test_group();

    $ws->add_group(group => $grp);
    is $ws->group_count, 1, 'group is only one in workspace';

    lives_ok { $grp->update_store({permission_set => 'self-join'}); }
        'update group permissions lives';

    is $grp->permission_set, 'self-join', 'group permission is updated';
    is $grp->display_permission_set, 'Self-Join',
        'group displayable permission set is correct';

    is $ws->permissions->current_set_name,
        'self-join', 'workspace permission is updated, too';
}

################################################################################
# TEST: update group perms, ws has individual members
update_perms_ws_has_users: {
    my $ws  = create_test_workspace();
    my $grp = create_test_group();
    my $user = create_test_user();

    $ws->add_group(group => $grp);
    is $ws->group_count, 1, 'group is only one in workspace';

    $ws->add_user(user => $user);
    is $ws->user_count, 1, 'workspace has a user';

    lives_ok { $grp->update_store({permission_set => 'self-join'}); }
        'update group permissions lives';

    is $grp->permission_set, 'self-join', 'group permission is updated';
    is $ws->permissions->current_set_name,
        'self-join', 'workspace permission is updated, too';
}

################################################################################
# TEST: update group perms, ws membership not solely controlled by group
update_perms_ws_not_controlled: {
    my $ws  = create_test_workspace();
    my $grp = create_test_group();
    my $other = create_test_group();

    $ws->add_group(group => $grp);
    $ws->add_group(group => $other);
    is $ws->group_count, 2, 'workspace has two groups';

    dies_ok { $grp->update_store({permission_set => 'self-join'}); }
        'update group permissions dies when workspace has other groups';

    is $grp->permission_set, 'private', 'group permission unchanged';
    is $other->permission_set, 'private', 'other group permission unchanged';
    is $ws->permissions->current_set_name,
        'member-only', 'workspace permission unchanged';
}

default_set_exported: {
    my $account = create_test_account_bypassing_factory();
    my $group = create_test_group(account => $account);
    my $export_dir = export_account($account);
    my $account_yaml = $export_dir.'/account.yaml';
    my $data = LoadFile($account_yaml);
    is $data->{groups}[0]{driver_group_name}, $group->display_name;
    is $data->{groups}[0]{permission_set}, $group->permission_set;
}

import_export_non_default: {
    my $account = create_test_account_bypassing_factory();
    my $group = create_test_group(account => $account);
    $group->update_store({permission_set => 'self-join'});
    my $acct_name = $account->name;
    my $group_name = $group->driver_group_name;

    export_and_reimport_account(
        account => $account,
        groups => [$group],
    );

    # re-load the group and account
    $account = Socialtext::Account->new(name => $acct_name);
    $group = Socialtext::Group->GetGroup(
        primary_account_id => $account->account_id,
        created_by_user_id => Socialtext::User->SystemUser->user_id,
        driver_group_name  => $group_name,
    );

    is $group->permission_set, 'self-join', 'permission set was preserved';
}

# TEST: Importing a Group that has no explicit Permission Set; testing the
# import of old exported Groups.
import_group_without_permission_set: {
    my $account = create_test_account_bypassing_factory();
    my $group   = create_test_group(account => $account);
    my $acct_name  = $account->name;
    my $group_name = $group->driver_group_name;

    # Export/import Group, removing the "permission_set" so it looks like its
    # an older export format.
    export_and_reimport_account(
        account => $account,
        groups  => [$group],
        mangle  => sub {
            my $data = shift;
            map { delete $_->{permission_set} } @{ $data->{groups} };
        },
    );

    # re-load Group, check for proper Permission Set
    $account = Socialtext::Account->new(name => $acct_name);
    $group   = Socialtext::Group->GetGroup(
        primary_account_id => $account->account_id,
        created_by_user_id => Socialtext::User->SystemUser->user_id,
        driver_group_name  => $group_name,
    );
    is $group->permission_set, 'private',
        'Missing permission_set set to a sane default';
    is $group->display_permission_set, 'Private',
        'display is correct';
}
