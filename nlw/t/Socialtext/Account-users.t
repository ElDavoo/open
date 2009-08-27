#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 8;

###############################################################################
# Fixtures: db
# - Need a DB, but don't care what's in it
fixtures(qw( db ));

###############################################################################
# TEST: a newly created Account has *no* Users in it
new_account_has_no_users: {
    my $account = create_test_account_bypassing_factory();
    my $count   = $account->user_count();
    is $count, 0, 'newly created Account has no Users in it';

    # Query the list of Users in the Account, make sure count matches
    #
    # NOTE: actual Users returned is tested in t/ST/Users-ByAccountId.t
    my $cursor = $account->users();
    isa_ok $cursor, 'Socialtext::MultiCursor', 'User cursor';
    is $cursor->count(), 0, '... with no Users in it';

    my $ids = $account->user_ids();
    is scalar(@{$ids}), 0, '... with no User Ids in it';
}

###############################################################################
# TEST: User count is correct
user_count_is_correct: {
    my $account = create_test_account_bypassing_factory();
    my $ws      = create_test_workspace(account => $account);
    my $group   = create_test_group();
    $ws->add_group(group => $group);

    # user: primary account
    my $user = create_test_user(account => $account);

    # user: secondary account, via UWR in WS
    $user = create_test_user();
    $ws->add_user(user => $user);

    my $count = $account->user_count();
    is $count, 2, 'Account has two Users';

    my $cursor = $account->users();
    isa_ok $cursor, 'Socialtext::MultiCursor', 'User cursor';
    is $cursor->count(), 2, '... with two Users in it';

    my $ids = $account->user_ids();
    is scalar(@{$ids}), 2, '... with two User Ids in it';

# XXX: YANK this out, we're not explicitly recording groups memberships right now.
#     # user: secondary account, via UGR+GWR in WS
#     $user = create_test_user();
#     $group->add_user(user => $user);
# 
#     # Query user count
#     my $count = $account->user_count();
#     is $count, 3, 'Account has three Users';
# 
#     # Query the list of Users in the Account, make sure count matches
#     #
#     # NOTE: actual Users returned is tested in t/ST/Users-ByAccountId.t
#     my $cursor = $account->users();
#     isa_ok $cursor, 'Socialtext::MultiCursor', 'User cursor';
#     is $cursor->count(), 3, '... with three Users in it';
# 
#     my $ids = $account->user_ids();
#     is scalar(@{$ids}), 3, '... with three User Ids in it';
}

###############################################################################
# XXX: This test is invalid untill we start explicitly adding group roles.
# TEST: User count is de-duped
# user_count_is_deduped: {
#     my $account = create_test_account_bypassing_factory();
#     my $ws      = create_test_workspace(account => $account);
#     my $group   = create_test_group();
#     $ws->add_group(group => $group);
# 
#     # user: primary account, plus UWR and UGR+GWR
#     my $user = create_test_user(account => $account);
#     $ws->add_user(user => $user);
#     $group->add_user(user => $user);
# 
#     # user: secondary account *only*, UWR and UGR+GWR
#     $user = create_test_user();
#     $ws->add_user(user => $user);
#     $group->add_user(user => $user);
# 
#     # Query user count
#     my $count = $account->user_count();
#     is $count, 2, 'Account has two Users';
# 
#     # Query the list of Users in the Account, make sure count matches
#     #
#     # NOTE: actual Users returned is tested in t/ST/Users-ByAccountId.t
#     my $cursor = $account->users();
#     isa_ok $cursor, 'Socialtext::MultiCursor', 'User cursor';
#     is $cursor->count(), 2, '... with two Users in it';
# 
#     my $ids = $account->user_ids();
#     is scalar(@{$ids}), 2, '... with two User Ids in it';
# }
