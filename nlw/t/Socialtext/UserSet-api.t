#!/usr/bin/perl
# @COPYRIGHT@
use warnings;
use strict;

use Test::Socialtext tests => 56;
use Test::Exception;
BEGIN {
    use_ok 'Socialtext::Group';
    use_ok 'Socialtext::Workspace';
    use_ok 'Socialtext::Account';
    use_ok 'Socialtext::User';
    use_ok 'Socialtext::UserSet';
}

fixtures(qw(db));

my $member = Socialtext::Role->new(name => 'member')->role_id;
my $admin = Socialtext::Role->new(name => 'admin')->role_id;

my $usr = create_test_user();

api_for_group: {
    check_api_for_container(create_test_group());
    check_api_for_container(create_test_account_bypassing_factory());
    check_api_for_container(create_test_workspace());
}

Bad_cases: {
    Add_user_to_user: {
        my $usr2 = create_test_user();
        my $uset = Socialtext::UserSet->new;

        my $user_id1 = $usr->user_id;
        my $user_id2 = $usr2->user_id;
        throws_ok {
            $uset->add_role($user_id1, $user_id2, $member);
        } qr/Can't add things to users/, "cannot add user to a user";
        throws_ok {
            $uset->remove_role($user_id1, $user_id2);
        } qr/edge $user_id1,$user_id2/, "cannot remove user from a user";
        throws_ok {
            $uset->update_role($user_id1, $user_id2, $member);
        } qr/edge $user_id1,$user_id2/, "cannot update user to a user";
    }

    Add_workspace_to_workspace: {
        my $wksp1 = create_test_workspace();
        my $wksp2 = create_test_workspace();
        my $uset = Socialtext::UserSet->new;

        my $uset_id1 = $wksp1->user_set_id;
        my $uset_id2 = $wksp2->user_set_id;
        throws_ok {
            $uset->add_role($uset_id1, $uset_id2, $member);
        } qr/Can't add workspaces to workspaces/, "cannot add wksp to a wksp";
        throws_ok {
            $uset->remove_role($uset_id1, $uset_id2);
        } qr/edge $uset_id1,$uset_id2/, "cannot remove wksp from a wksp";
        throws_ok {
            $uset->update_role($uset_id1, $uset_id2, $member);
        } qr/edge $uset_id1,$uset_id2/, "cannot update wksp to a wksp";
    }

    # consider adding these
    fail "todo: can't add account to account";
    fail "todo: adding group to a group is fine though";
}


sub check_api_for_container {
    my $cont = shift;
    ok $cont, "got a container";
    ok $cont->user_set_id, "has a user_set_id";
    my $uset = $cont->user_set;
    is $uset->owner_id, $cont->user_set_id, "same set id";
    is $uset->owner, $cont, "owner assigned";

    lives_ok {
        $uset->add_object_role($usr, $member);
    } "added user to the container";

    ok  $uset->connected($usr->user_id,     $cont->user_set_id),
        "user is in the container";
    ok !$uset->connected($cont->user_set_id, $usr->user_id),
        "doesn't mean the container is in the user";

    ok $uset->has_role($usr->user_id, $cont->user_set_id, $member);
    ok $uset->has_direct_role($usr->user_id, $cont->user_set_id, $member);

    lives_ok {
        $uset->update_object_role($usr, $admin);
    } "role updated";
    ok !$uset->has_role($usr->user_id, $cont->user_set_id, $member);
    ok  $uset->has_role($usr->user_id, $cont->user_set_id, $admin);

    lives_ok {
        $uset->remove_object_role($usr);
    } "role updated";
    ok !$uset->has_role($usr->user_id, $cont->user_set_id, $member);
    ok !$uset->has_role($usr->user_id, $cont->user_set_id, $admin);
    ok !$uset->connected($usr->user_id, $cont->user_set_id);
}
