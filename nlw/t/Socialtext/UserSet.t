#!/usr/bin/perl
# @COPYRIGHT@
use warnings;
use strict;

use Test::Socialtext tests => 129;
use Test::Differences;
use Test::Exception;
use List::Util qw/shuffle/;
use Socialtext::SQL qw/get_dbh/;
BEGIN {
    use_ok 'Socialtext::UserSet', qw/:const/;
}

fixtures(qw(db destructive));
my $dbh = get_dbh();
ok $dbh;
$dbh->{AutoCommit} = 1;
my $OFFSET = GROUP_OFFSET + 1_000_000;
my $uset = Socialtext::UserSet->new;

my $member = Socialtext::Role->new(name => 'member')->role_id;
ok $member;
my $guest  = Socialtext::Role->new(name => 'guest')->role_id;
ok $guest;

sub reset_graph {
    local $dbh->{RaiseError} = 1;
    $dbh->do(q{ TRUNCATE user_set_include, user_set_path });
}

sub insert { $uset->add_role(shift(@_) + $OFFSET, shift(@_) + $OFFSET, @_); }
sub del { $uset->remove_role(shift(@_) + $OFFSET, shift(@_) + $OFFSET, @_); }
sub update {
    $uset->update_role(shift(@_) + $OFFSET, shift(@_) + $OFFSET, @_);
}
sub del_set { $uset->remove_set(shift(@_) + $OFFSET, @_); }

sub connected {
    $uset->connected(shift(@_) + $OFFSET, shift(@_) + $OFFSET, @_) ? 1 : 0;
}

sub directly_connected {
    $uset->directly_connected(shift(@_) + $OFFSET, shift(@_) + $OFFSET, @_) ? 1 : 0;
}

sub has_role {
    $uset->has_role(shift(@_) + $OFFSET, shift(@_) + $OFFSET, @_) ? 1 : 0;
}

sub has_direct_role {
    $uset->has_direct_role(shift(@_) + $OFFSET, shift(@_) + $OFFSET, @_) ? 1 : 0;
}

sub has_plugin {
    $uset->has_plugin(shift(@_) + $OFFSET, @_) ? 1 : 0;
}

sub roles {
    $uset->roles(shift(@_) + $OFFSET, shift(@_) + $OFFSET, @_);
}

sub direct_role {
    $uset->direct_role(shift(@_) + $OFFSET, shift(@_) + $OFFSET, @_);
}

reset_graph();

bipartite: {
    insert(2,3);
    ok has_role(2,3,$member);

    is connected(2,3), 1, "new edge is a path";
    is connected(3,2), 0, "graph is directed";
    is connected(2,4), 0;

    insert(5,6);
    is connected(5,6), 1, "new edge is a path";
    is connected(6,5), 0, "directed";

    is_graph_tc(
        [2,3 => 2,3],
        [5,6 => 5,6],
    );
    # 2 -> 3    5 -> 6

    del(5,6);
    dies_ok { del(5,6) } "second delete dies";
    is connected(5,6), 0, "edge removed";
    is connected(2,3), 1, "first one still there";
}

ingress: {
    reset_graph();
    # 2 -> 3    5 -> 6
    insert(2,3);
    insert(5,6);
    is_graph_tc(
        [2,3 => 2,3],
        [5,6 => 5,6],
    );

    insert(1,2);
    # 1 -> 2 -> 3    5 -> 6
    is connected(1,2), 1, "new edge is a path";
    is connected(2,1), 0, "directed";
    is connected(1,3), 1, "ingres makes transitive path";
    is connected(2,3), 1, "old path there still too";

    is_graph_tc(
        [1,3 => 1,2,3],
        [1,2 => 1,2],
        [2,3 => 2,3],
        [5,6 => 5,6],
    );

    del(1,2);
    is connected(1,2), 0, "new path removed";
    is connected(1,3), 0, "no more transitive path on removal";
    is connected(2,3), 1, "old path still there";

    is_graph_tc(
        [2,3 => 2,3],
        [5,6 => 5,6],
    );
    # 2 -> 3    5 -> 6
}

egress: { 
    reset_graph();
    insert(2,3);
    insert(5,6);
    # 2 -> 3    5 -> 6
    is_graph_tc(
        [2,3 => 2,3],
        [5,6 => 5,6],
    );
    
    insert(6,7);
    # 2 -> 3    5 -> 6 -> 7
    is connected(6,7), 1, "new edge is a path";
    is connected(7,6), 0, "directed";
    is connected(5,7), 1, "ingres makes transitive path";
    is connected(5,6), 1, "old path there still too";

    is_graph_tc(
        [2,3 => 2,3],
        [5,6 => 5,6],
        [5,7 => 5,6,7],
        [6,7 => 6,7],
    );

    del(6,7);
    is connected(6,7), 0, "new path removed";
    is connected(5,7), 0, "no more transitive path on removal";
    is connected(5,6), 1, "old path still there";

    is_graph_tc(
        [2,3 => 2,3],
        [5,6 => 5,6],
    );
    # 2 -> 3    5 -> 6
}

simple_join: { 
    reset_graph();
    insert(2,3);
    insert(5,6);
    # 2 -> 3    5 -> 6
    is_graph_tc(
        [2,3 => 2,3],
        [5,6 => 5,6],
    );

    insert(3,5);
    # 2 -> 3 -> 5 -> 6
    is connected(3,5), 1, "new edge is a path";
    is connected(5,3), 0, "directed";
    is connected(2,6), 1, "joiner makes transitive path";
    ok has_role(2,6 => $member), "joiner makes member role";

    update(5,6 => $guest);
    ok has_role(2,3 => $member);
    ok has_role(2,5 => $member);
    ok has_role(3,5 => $member);
    ok has_role(2,6 => $guest), "guest role got updated";
    ok has_role(3,6 => $guest), "guest role got updated";
    ok has_role(5,6 => $guest), "guest role got updated";

    is_graph_tc(
        [2,3 => 2,3],
        [2,5 => 2,3,5],
        [2,6 => 2,3,5,6],

        [3,5 => 3,5],
        [3,6 => 3,5,6],

        [5,6 => 5,6],
    );

    del(3,5);
    is connected(3,5), 0, "new path removed";
    is connected(2,6), 0, "no more transitive path on removal";

    is_graph_tc(
        [2,3 => 2,3],
        [5,6 => 5,6],
    );
    # 2 -> 3    5 -> 6
}

the_x: { 
    reset_graph();
    insert(2,3);
    insert(1,3);
    insert(5,6);
    insert(5,7);
    #      1    7
    #      V    ^
    # 2 -> 3    5 -> 6
    is_graph_tc(
        [2,3 => 2,3],
        [1,3 => 1,3],
        [5,6 => 5,6],
        [5,7 => 5,7],
    );

    insert(3,5);
    #      1    7
    #      V    ^
    # 2 -> 3 -> 5 -> 6

    is connected(3,5), 1, "new edge is a path";
    is connected(5,3), 0, "directed";
    is connected(2,6), 1, "joiner makes some transitive paths";
    is connected(2,7), 1, "joiner makes some transitive paths";
    is connected(1,6), 1, "joiner makes some transitive paths";
    is connected(1,7), 1, "joiner makes some transitive paths";

    update(5,7 => $guest);
    ok has_role(5,7 => $guest);
    ok has_role(3,7 => $guest);
    ok has_role(1,7 => $guest);
    ok has_role(2,7 => $guest);
    ok has_role(5,6 => $member);
    ok has_role(3,5 => $member);

    is_graph_tc(
        [1,3 => 1,3],
        [1,5 => 1,3,5],
        [1,6 => 1,3,5,6],
        [1,7 => 1,3,5,7],

        [2,3 => 2,3],
        [2,5 => 2,3,5],
        [2,6 => 2,3,5,6],
        [2,7 => 2,3,5,7],

        [3,5 => 3,5],
        [3,6 => 3,5,6],
        [3,7 => 3,5,7],

        [5,6 => 5,6],
        [5,7 => 5,7],
    );

    del(3,5);
    is connected(3,5), 0, "new path removed";
    is connected(2,6), 0, "joiner removal removes transitive paths";
    is connected(2,7), 0, "joiner removal removes transitive paths";
    is connected(1,6), 0, "joiner removal removes transitive paths";
    is connected(1,7), 0, "joiner removal removes transitive paths";

    is_graph_tc(
        [2,3 => 2,3],
        [1,3 => 1,3],
        [5,6 => 5,6],
        [5,7 => 5,7],
    );

    del(1,3);
    del(5,7);
    is_graph_tc(
        [2,3 => 2,3],
        [5,6 => 5,6],
    );
}

triangle: {
    reset_graph();
    # 1 -> 2 -> 3
    insert(1,2);
    insert(2,3);

    is_graph_tc(
        [1,2 => 1,2],
        [1,3 => 1,2,3],
        [2,3 => 2,3],
    );

    # 1 -> 2 -> 3 -> 1
    insert(3,1);

    is_graph_tc(
        [1,1 => 1,2,3,1],
        [1,2 => 1,2],
        [1,3 => 1,2,3],

        [2,1 => 2,3,1],
        [2,2 => 2,3,1,2],
        [2,3 => 2,3],

        [3,1 => 3,1],
        [3,2 => 3,1,2],
        [3,3 => 3,1,2,3],
    );

    ok has_role(1,1 => $member);
    ok has_role(1,2 => $member);
    ok has_role(1,3 => $member);

    # bogus update has no effect, "1,1" is a virtual role:
    dies_ok { update(1,1 => $guest) };
    ok has_role(1,1 => $member), "bogus role update has no effect";
    ok has_role(2,1 => $member), "bogus role update has no effect";
    ok has_role(3,1 => $member), "bogus role update has no effect";

    update(1,2 => $guest);
    ok has_role(1,2 => $guest), "real role update, 1 in 2 is guest";
    ok has_role(2,2 => $guest), "real role update, 2 in 2 is guest";
    ok has_role(3,2 => $guest), "real role update, 3 in 2 is guest";
    ok has_role(1,1 => $member), "1 in 1 remains member";
    ok has_role(2,1 => $member), "2 in 1 remains member";
    ok has_role(3,1 => $member), "3 in 1 remains member";
    ok has_role(1,3 => $member), "1 in 3 remains member";
    ok has_role(2,3 => $member), "2 in 3 remains member";
    ok has_role(3,3 => $member), "3 in 3 remains member";

    del(3,1);
    is_graph_tc(
        [1,2 => 1,2],
        [1,3 => 1,2,3],
        [2,3 => 2,3],
    );

    del(2,3);
    is_graph_tc(
        [1,2 => 1,2],
    );

    del(1,2);
    is_graph_tc();
}

reset_graph();

figure_eight: {
    #       + --- 4
    #       v     ^
    # 1 --> 2 --> 3
    # ^     |     
    # 5 <---+

    insert(1,2);
    insert(2,3);
    insert(3,4);
    insert(4,2);

    is_graph_tc(
        [1,2 => 1,2],
        [1,3 => 1,2,3],
        [1,4 => 1,2,3,4],

        [2,2 => 2,3,4,2],
        [2,3 => 2,3],
        [2,4 => 2,3,4],

        [3,2 => 3,4,2],
        [3,3 => 3,4,2,3],
        [3,4 => 3,4],

        [4,2 => 4,2],
        [4,3 => 4,2,3],
        [4,4 => 4,2,3,4],
    );

    insert(2,5);

    is_graph_tc(
        [1,2 => 1,2],
        [1,3 => 1,2,3],
        [1,4 => 1,2,3,4],
        [1,5 => 1,2,5],

        [2,2 => 2,3,4,2],
        [2,3 => 2,3],
        [2,4 => 2,3,4],
        [2,5 => 2,5],

        [3,2 => 3,4,2],
        [3,3 => 3,4,2,3],
        [3,4 => 3,4],
        [3,5 => 3,4,2,5],

        [4,2 => 4,2],
        [4,3 => 4,2,3],
        [4,4 => 4,2,3,4],
        [4,5 => 4,2,5],
    );

    insert(5,1);

    is_graph_tc(
        [1,1 => 1,2,5,1],
        [1,2 => 1,2],
        [1,3 => 1,2,3],
        [1,4 => 1,2,3,4],
        [1,5 => 1,2,5],

        [2,1 => 2,5,1],
        [2,2 => 2,3,4,2], # top loop
        [2,2 => 2,5,1,2], # bottom loop
        [2,3 => 2,3],
        [2,4 => 2,3,4],
        [2,5 => 2,5],

        [3,1 => 3,4,2,5,1],
        [3,2 => 3,4,2],
        [3,3 => 3,4,2,3],
        [3,4 => 3,4],
        [3,5 => 3,4,2,5],

        [4,1 => 4,2,5,1],
        [4,2 => 4,2],
        [4,3 => 4,2,3],
        [4,4 => 4,2,3,4],
        [4,5 => 4,2,5],

        [5,1 => 5,1],
        [5,2 => 5,1,2],
        [5,3 => 5,1,2,3],
        [5,4 => 5,1,2,3,4],
        [5,5 => 5,1,2,5],
    );
    print_tbls();

    ok connected(2,2);
    del(4,2);
    ok connected(2,2);
    del(5,1);
    ok !connected(2,2);
    is_graph_tc(
        [1,2 => 1,2],
        [1,3 => 1,2,3],
        [1,4 => 1,2,3,4],
        [1,5 => 1,2,5],
        [2,3 => 2,3],
        [2,4 => 2,3,4],
        [2,5 => 2,5],
        [3,4 => 3,4],
    );

    del(@$_) for shuffle([1,2],[2,3],[3,4],[2,5]);
    is_graph_tc();
}

reset_graph();

delete_accuracy: {
    insert(1,2);
    insert(2,1);
    insert(1,21);
    insert(11,21);
    insert(11,12);
    insert(111,121);

    del(11,12);
    is_graph_tc(
        [1,2 => 1,2],
        [1,1 => 1,2,1],
        [2,1 => 2,1],
        [2,2 => 2,1,2],
        [2,21 => 2,1,21],
        [1,21 => 1,21],
        [11,21 => 11,21],
        [111,121 => 111,121],
    );

    del(2,1);
    is_graph_tc(
        [1,2 => 1,2],
        [1,21 => 1,21],
        [11,21 => 11,21],
        [111,121 => 111,121],
    );

    del(11,21);
    is_graph_tc(
        [1,2 => 1,2],
        [1,21 => 1,21],
        [111,121 => 111,121],
    );
}

remove_set: {
    reset_graph();
    lives_ok {
        insert(1,2);
        insert(2,3);
        insert(3,4);
        insert(5,4);
    } "created graph for testing set removal";
    
    is_graph_tc(
        [1,2 => 1,2],
        [1,3 => 1,2,3],
        [1,4 => 1,2,3,4],
        [2,3 => 2,3],
        [2,4 => 2,3,4],
        [3,4 => 3,4],
        [5,4 => 5,4],
    );

    dies_ok {
        del_set(7);
    } "can't delete a set that doesn't exist";

    lives_ok {
        del_set(3);
    } "deleted set 3";

    is_graph_tc(
        [1,2 => 1,2],
        [5,4 => 5,4],
    );
}

has_plugin: {
    reset_graph();
    insert(1,2);
    insert(2,3);
    $dbh->do(qq{INSERT INTO user_set_plugin VALUES (3+$OFFSET, 'testin')});
    ok has_plugin(1,'testin'), "transitive connection to plugin";
    ok has_plugin(2,'testin'), "transitive connection to plugin";
    ok has_plugin(3,'testin'), "transitive connection to plugin";
    del_set(2);
    ok !has_plugin(1,'testin'), "transitive connection to plugin removed";
    ok !has_plugin(2,'testin'), "transitive connection to plugin removed";
    ok has_plugin(3,'testin'), "directly connected to plugin still";
    $dbh->do(qq{DELETE FROM user_set_plugin WHERE user_set_id = 3+$OFFSET});
    ok !has_plugin(3,'testin'), "plugin turned off";
}

direct: {
    reset_graph();
    insert(1,2);
    insert(2,3);

    ok has_role(1,3,$member);
    ok !has_direct_role(1,3,$member);
    ok has_direct_role(1,2,$member);
    ok has_direct_role(2,3,$member);

    ok connected(1,3);
    ok !directly_connected(1,3);
    ok directly_connected(1,2);
    ok directly_connected(2,3);
}

role_list: {
    reset_graph();
    insert(1,2, $member);
    insert(2,3, $guest);
    insert(1,3, $member);
    insert(1,4, $member);

    eq_or_diff [roles(1,3)],[sort {$a<=>$b} $member,$guest];
    eq_or_diff [roles(2,3)],[$guest];
    eq_or_diff [roles(1,4)],[$member];

    is direct_role(1,3),$member;
    is direct_role(2,3),$guest;
    is direct_role(2,4),undef;
    is direct_role(1,4),$member;
}

reset_graph();

sub is_graph_tc {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my @expected_paths;
    for my $pathref (@_) {
        my ($path_start, $path_end, @vlist) = @$pathref;
        my @segs = map {$vlist[$_].','.$vlist[$_+1]} (0..($#vlist-1));
        push @expected_paths,"$path_start,$path_end : ".join(',',@vlist);
    }
    @expected_paths = sort(@expected_paths);

    my $sth = $dbh->prepare(qq{
        SELECT from_set_id-$OFFSET,into_set_id-$OFFSET,vlist
        FROM user_set_path
    });
    $sth->execute();
    my @got_paths;
    while (my $got_path = $sth->fetchrow_arrayref()) {
        my ($from,$to,$vlist) = @$got_path;
        $vlist = join(',',map { $_-$OFFSET} @$vlist);
        push @got_paths, "$from,$to : $vlist";
    }
    @got_paths = sort @got_paths;
    eq_or_diff \@got_paths, \@expected_paths, "table is as expected";
}

sub print_tbls {
    my $view = $dbh->selectall_arrayref(qq{
        SELECT from_set_id-$OFFSET,via_set_id-$OFFSET,into_set_id-$OFFSET,role.name,vlist
        FROM user_set_path
        JOIN "Role" role USING (role_id)
        ORDER BY from_set_id ASC,into_set_id ASC
    });
    diag "maint table:";
    diag "from\tvia\tinto\trole\tvlist";
    for my $row (@$view) {
        my $vlist = pop @$row;
        push @$row, '{'.join(',',map {$_-$OFFSET} @$vlist).'}';
        diag join("\t",@$row);
    }

    $view = $dbh->selectall_arrayref(qq{
        SELECT from_set_id-$OFFSET,into_set_id-$OFFSET,role.name
        FROM user_set_include
        JOIN "Role" role USING (role_id)
        ORDER BY from_set_id ASC, into_set_id ASC
    });
    diag "real table:";
    diag "from\tinto\trole";
    for my $row (@$view) {
        diag join("\t", @$row);
    }

    $view = $dbh->selectall_arrayref(qq{
        SELECT from_set_id-$OFFSET,into_set_id-$OFFSET,role.name
        FROM user_set_include_tc
        JOIN "Role" role USING (role_id)
        ORDER BY from_set_id,into_set_id ASC
    });
    diag "transitive closure:";
    diag "from\tinto\trole";
    for my $row (@$view) {
        diag join("\t", @$row);
    }
}

