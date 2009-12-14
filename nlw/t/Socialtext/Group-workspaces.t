#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::Socialtext tests => 6;

###############################################################################
# Fixtures: db
# - need a DB, but don't care what's in it.
fixtures(qw( db ));

use_ok 'Socialtext::Group';

################################################################################
# TEST: Group is in no Workspaces; has no GWRs
group_with_no_workspaces: {
    my $group      = create_test_group();
    my $workspaces = $group->workspaces();

    isa_ok $workspaces, 'Socialtext::MultiCursor', 'got a list of workspaces';
    is $workspaces->count(), 0, '... with the correct count';
}

################################################################################
# TEST: Group has Role in some Workspaces
group_has_workspaces: {
    my $user   = create_test_user();
    my $ws_one = create_test_workspace(user => $user);
    my $ws_two = create_test_workspace(user => $user);
    my $group  = create_test_group();

    # Create GWRs, giving the Group a default Role
    $ws_one->add_group(group => $group);
    $ws_two->add_group(group => $group);

    my $workspaces = $group->workspaces();

    isa_ok $workspaces, 'Socialtext::MultiCursor', 'got a list of workspaces';
    is $workspaces->count(), 2, '... with the correct count';
    isa_ok $workspaces->next(), 'Socialtext::Workspace', '... queried Workspace';
}
