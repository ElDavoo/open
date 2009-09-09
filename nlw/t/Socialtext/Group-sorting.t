#!perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::Socialtext tests => 53;
use Test::Exception;
use Socialtext::SQL qw/:exec/;

fixtures(qw(db));

use_ok 'Socialtext::Group';

my $account =  create_test_account_bypassing_factory("Account AAA $^T");
my $account2 = create_test_account_bypassing_factory("Account BBB $^T");
our $sort_method; # localized in test blocks
my $devvy = create_test_user(email_address => "devvy$^T\@socialtext.com");
my $nully = create_test_user(email_address => "nully$^T\@socialtext.com");

sub is_sort ($$@) {
    my $order_by = shift;
    my $sort_order = shift;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $sorted;
    if ($sort_method eq 'ByAccountId') {
        $sorted = Socialtext::Group->ByAccountId(
            account_id => $account->account_id,
            order_by => $order_by,
            sort_order => $sort_order,
            include_aggregates => 1,
        );
    }
    else {
        $sorted = Socialtext::Group->All(
            order_by => $order_by,
            sort_order => $sort_order,
            include_aggregates => 1,
        );
    }
    ok $sorted, "got result from $sort_method";

    my @all = $sorted->all;
    is_deeply [ map { $_->group_id } @all ],
              [ map { $_->group_id } (@_) ],
              "sorted by $order_by in $sort_order order";
}

for my $method ('ByAccountId','All') {
    local $sort_method = $method;

    # create some Groups, *not* in alphabetical order; so we know when we get
    # them back that they're not just returned in "the order they were stuffed
    # in", but are actually in a sorted order.

    my $g1_zzz = create_test_group(
        account   => $account,
        unique_id => 'Group ZZZ',
        user => $nully,
    );
    $g1_zzz->add_user(user => create_test_user(account=>$account)) for (1..2);
    create_test_workspace(account => $account)->add_group(group=>$g1_zzz) for (1..3);

    my $g2_aaa = create_test_group(
        account   => ($method eq 'All') ? $account2 : $account,
        unique_id => 'Group AAA',
        user => $nully,
    );
    $g2_aaa->add_user(user => create_test_user(account=>$account)) for (1..3);
    create_test_workspace(account => $account)->add_group(group=>$g2_aaa) for (1..3);

    my $g3_bbb = create_test_group(
        account   => $account,
        unique_id => 'Group BBB',
        user => $devvy,
    );
    # no users or workspaces

    is_sort driver_group_name => 'asc',  $g2_aaa, $g3_bbb, $g1_zzz;
    is_sort driver_group_name => 'desc', $g1_zzz, $g3_bbb, $g2_aaa;

    is_sort group_id => 'asc',  $g1_zzz, $g2_aaa, $g3_bbb;
    is_sort group_id => 'desc', $g3_bbb, $g2_aaa, $g1_zzz;

    is_sort creation_datetime => 'asc',  $g1_zzz, $g2_aaa, $g3_bbb;
    is_sort creation_datetime => 'desc', $g3_bbb, $g2_aaa, $g1_zzz;

    # Note: sub-sorted by group name and ID (ascending)

    is_sort creator => 'asc',  $g3_bbb, $g2_aaa, $g1_zzz;
    is_sort creator => 'desc', $g2_aaa, $g1_zzz, $g3_bbb;

    is_sort user_count => 'asc',  $g3_bbb, $g1_zzz, $g2_aaa;
    is_sort user_count => 'desc', $g2_aaa, $g1_zzz, $g3_bbb;

    is_sort workspace_count => 'asc',  $g3_bbb, $g2_aaa, $g1_zzz;
    is_sort workspace_count => 'desc', $g2_aaa, $g1_zzz, $g3_bbb;

    if ($method eq 'All') {
        is_sort primary_account => 'asc',  $g3_bbb, $g1_zzz, $g2_aaa;
        is_sort primary_account => 'desc', $g2_aaa, $g3_bbb, $g1_zzz;
    }

    $g1_zzz->delete();
    $g2_aaa->delete();
    $g3_bbb->delete();
}
