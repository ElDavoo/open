#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 16;
use Test::Exception;

###############################################################################
# Fixtures: db
fixtures(qw( admin ));

use_ok 'Socialtext::UserWorkspaceRole';

###############################################################################
# TEST: instantiation
instantiation: {
    my $uwr = Socialtext::UserWorkspaceRole->new( {
        user_id      => 1,
        workspace_id => 2,
        role_id      => 3,
        is_selected  => 0,
    } );
    isa_ok $uwr, 'Socialtext::UserWorkspaceRole';
    is $uwr->user_id,  1, '... with the provided user_id';
    is $uwr->workspace_id, 2, '... with the provided workspace_id';
    is $uwr->role_id,  3, '... with the provided role_id';
    is $uwr->is_selected, 0, '... with proper is_selected value';
}

###############################################################################
# TEST: instantiation with additional attributes
instantiation_with_extra_attributes: {
    my $uwr;
    lives_ok sub {
        $uwr = Socialtext::UserWorkspaceRole->new( {
            user_id      => 1,
            workspace_id => 2,
            role_id      => 3,
            is_selected  => 0,
            bogus        => 'attribute',
        } );
    }, 'created UWR when additional attributes provided';
    isa_ok $uwr, 'Socialtext::UserWorkspaceRole', '... created UWR';
}

###############################################################################
# TEST: instantiation with actual User/Workspace/Role
instantiation_with_real_data: {
    my $user = create_test_user();
    my $ws   = create_test_workspace();
    my $role = Socialtext::Role->new(name => 'member');
    my $uwr  = Socialtext::UserWorkspaceRole->new( {
        user_id      => $user->user_id,
        workspace_id => $ws->workspace_id,
        role_id      => $role->role_id,
        is_selected  => 1,
    } );
    isa_ok $uwr, 'Socialtext::UserWorkspaceRole';

    is $uwr->user_id,    $user->user_id,
        '... with the provided user_id';
    is $uwr->workspace_id, $ws->workspace_id,
        '... with the provided workspace_id';
    is $uwr->role_id,    $role->role_id,
        '... with the provided role_id';
    is $uwr->is_selected, 1,
        '... with proper is_selected value';

    is $uwr->user->user_id,       $user->user_id,
        '... with the right inflated User object';
    is $uwr->workspace->workspace_id, $ws->workspace_id,
        '... with the right inflated Workspace object';
    is $uwr->role->role_id,       $role->role_id,
        '... with the right inflated Role object';
}

