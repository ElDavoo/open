#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 6;

fixtures(qw( db ));

BEGIN { use_ok('Socialtext::Search::Set') }

###############################################################################
# TEST: each user gets their own Search Set, even if they have same name
distinct_search_sets: {
    my $user_one = create_test_user();
    my $set_one  = Socialtext::Search::Set->create(
        name => 'xyzzy',
        user => $user_one,
    );
    isa_ok $set_one, 'Socialtext::Search::Set';

    my $user_two = create_test_user();
    my $set_two  = Socialtext::Search::Set->create(
        name => 'xyzzy',
        user => $user_two,
    );
    isa_ok $set_two, 'Socialtext::Search::Set';

    isnt $set_one->search_set_id, $set_two->search_set_id,
        'Different Users with same named Search Set have distince ids';
}

###############################################################################
# TEST: List the Workspaces in a Search Set.
list_workspaces: {
    my $user = create_test_user();
    my $set  = Socialtext::Search::Set->create(
        name => 'xyzzy',
        user => $user,
    );
    isa_ok $set, 'Socialtext::Search::Set';

    my $ws_one   = create_test_workspace();
    my $ws_two   = create_test_workspace();
    my $ws_three = create_test_workspace();
    my @names    = map { $_->name } ($ws_one, $ws_two, $ws_three);

    $set->add_workspace_name($_) for @names;

    my @queried = $set->workspace_names->all;
    is_deeply \@queried, \@names, 'correct list of Workspaces';
}
