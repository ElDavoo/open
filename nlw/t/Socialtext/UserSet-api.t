#!/usr/bin/perl
# @COPYRIGHT@
use warnings;
use strict;

use Test::Socialtext tests => 27;
use Test::Exception;
use Socialtext::SQL qw/get_dbh/;
BEGIN {
    use_ok 'Socialtext::Group';
    use_ok 'Socialtext::Workspace';
    use_ok 'Socialtext::Account';
    use_ok 'Socialtext::User';
    use_ok 'Socialtext::UserSet';
}

fixtures(qw(db));

my $dbh = get_dbh();
my $member = Socialtext::Role->new(name => 'member')->role_id;
my $guest = Socialtext::Role->new(name => 'guest')->role_id;

my $usr = create_test_user();

api: {
    my $grp = create_test_group();
    ok $grp, "got a group";
    ok $grp->user_set_id, "has a user_set_id";
    my $uset = $grp->user_set;
    is $uset->owner_id, $grp->user_set_id, "same set id";
    is $uset->owner, $grp, "owner assigned";
    is $uset->dbh, $dbh, "dbh assigned";

    lives_ok {
        $uset->add_object_role($usr, $member);
    } "added user to the group";

    ok  $uset->connected($usr->user_id,     $grp->user_set_id),
        "user is in the group";
    ok !$uset->connected($grp->user_set_id, $usr->user_id),
        "doesn't mean the group is in the user";

    ok $uset->has_role($usr->user_id, $grp->user_set_id, $member);

    lives_ok {
        $uset->update_object_role($usr, $guest);
    } "role updated";
    ok !$uset->has_role($usr->user_id, $grp->user_set_id, $member);
    ok  $uset->has_role($usr->user_id, $grp->user_set_id, $guest);

    lives_ok {
        $uset->remove_object_role($usr);
    } "role updated";
    ok !$uset->has_role($usr->user_id, $grp->user_set_id, $member);
    ok !$uset->has_role($usr->user_id, $grp->user_set_id, $guest);
    ok !$uset->connected($usr->user_id, $grp->user_set_id);
}

Bad_cases: {
    my $usr2 = create_test_user();
    my $uset = Socialtext::UserSet->new(dbh => $dbh);

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


    # consider adding these
    fail "todo: can't add workspace to workspace";
    fail "todo: can't add account to account";
    fail "todo: adding group to a group is fine though";
}

