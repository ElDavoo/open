#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 63;
use Test::Socialtext::Fatal;
use Scalar::Util qw/refaddr/;

fixtures( 'db' );

BEGIN {
    use_ok 'Socialtext::SQL', qw( 
        get_dbh disconnect_dbh invalidate_dbh with_local_dbh
        :exec :bool :txn :time
        sql_ensure_temp
    );
}

ok !exception { disconnect_dbh() }, "can disconnect okay";
ok !exception { get_dbh() }, "can connect okay";

sql_execute: {
    my $sth;
    sql_execute('CREATE TABLE foo (name text)');
    $sth = sql_execute('SELECT * FROM foo');
    is_deeply $sth->fetchall_arrayref, [], 'no data found in table';

    invalidate_dbh();

    sql_execute(q{INSERT INTO foo VALUES ('luke')});
    $sth = sql_execute('SELECT * FROM foo');
    is_deeply $sth->fetchall_arrayref, [ ['luke' ] ], 'data found in table';

    { 
        ##local $SIG{__WARN__} = sub { };
        sql_execute('DROP TABLE foo');
        eval { sql_execute('SELECT * FROM foo') };
        ok $@, "table was deleted";
    }
}

old_school_transactions: {
    my @warnings;
    ok !exception {
        local $SIG{__WARN__} = sub {push @warnings, $_[0]};
        sql_rollback();
    }, "rollback outside of transaction is not fatal";
    ok @warnings == 1, "got a warning";
    @warnings = ();

    ok !exception {
        local $SIG{__WARN__} = sub {push @warnings, $_[0]};
        sql_commit();
    }, "outside of transaction is not fatal";
    ok @warnings == 1, "got a warning";
    @warnings = ();

    ok get_dbh->{AutoCommit}, "AutoCommit it turned on";
    ok !sql_in_transaction(), 'not in transaction';

    ok !exception { sql_begin_work() }, 'begin';

    ok !get_dbh->{AutoCommit}, "AutoCommit becomes disabled";
    ok sql_in_transaction(), 'in transaction';

    ok !exception { sql_rollback() }, 'rollback';

    ok get_dbh->{AutoCommit}, "AutoCommit it turned on again";
    ok !sql_in_transaction(), 'not in transaction';

    my $tt = q{
        CREATE TEMPORARY TABLE goes_away (id bigint NOT NULL) ON COMMIT DROP
    };

    ok exception {
        sql_execute($tt);
        sql_singlevalue("SELECT * FROM goes_away LIMIT 1");
    }, "should die because no txn started";

    sql_begin_work();
    ok !exception {
        sql_execute($tt);
        sql_singlevalue("SELECT * FROM goes_away LIMIT 1");
    }, "should be fine because txn in progress";
    sql_commit();

    sql_begin_work();
    sql_execute($tt);

    ok !exception {
        local $SIG{__WARN__} = sub {push @warnings, join('',@_)};
        invalidate_dbh();
    }, "invalidating while in txn is not fatal";
    ok @warnings == 2, "get a set of warnings";
    @warnings = ();
    ok !sql_in_transaction(), 'not in transaction';
}

sql_execute_array: {
    my $sth;
    sql_execute('CREATE TABLE bar (name text, value text)');

    sql_execute_array(
        q{INSERT INTO bar VALUES (?,?)},
        {},
        [ map { "name $_" } 0 .. 10 ],
        [ map { "value $_" } 0 .. 10 ],
    );
    $sth = sql_execute('SELECT * FROM bar');
    is_deeply $sth->fetchall_arrayref, [ 
        map { ["name $_", "value $_"] } 0 .. 10 
    ], 'data found in table';

    { 
        local $SIG{__WARN__} = sub { };
        sql_execute('DROP TABLE bar');
        eval { sql_execute('SELECT * FROM bar') };
        ok $@, "table was deleted";
    }
}

sql_execute_array_errors: {
    eval { sql_execute('DROP TABLE parent (id integer)'); };
    sql_begin_work();

    sql_execute('CREATE TEMPORARY TABLE parent (id integer) ON COMMIT DROP');
    sql_execute(
        'ALTER TABLE parent ADD CONSTRAINT parent_id_pk PRIMARY KEY (id)'
    );
    sql_execute('CREATE TEMPORARY TABLE child (id integer, dad integer) ON COMMIT DROP');
    sql_execute('
        ALTER TABLE child ADD CONSTRAINT parent_id_fk
         FOREIGN KEY (dad) REFERENCES parent(id)
    ');

    sql_execute_array('INSERT INTO parent values (?)', {}, [1,2,3,4,5]);
    my $dbh = get_dbh;
    $dbh->pg_savepoint('foo');
    like exception {
        sql_execute_array(
            'INSERT INTO child values (?, ?)', {},
            [1,2,3,4,5], [1,2,3,7,5],
        );
    }, qr{violates foreign key constraint "parent_id_fk"},
        "foreign key constraint violation";
    $dbh->pg_rollback_to('foo');

    ok !exception {
        sql_execute("SELECT * FROM parent");
    }, "savepoint worked okay";

    sql_rollback();
}

SQL_CONVERT_TO_BOOLEAN: {
    my $value = 0;
    my $sql_value = sql_convert_to_boolean($value,'t');
    is($sql_value, 'f', 'false if f');

    $value = 1;
    $sql_value = sql_convert_to_boolean($value,'f');
    is($sql_value, 't', 'true if t');

    $value = undef;
    $sql_value = sql_convert_to_boolean($value,'t');
    is($sql_value, 't', 'default works');
}

SQL_CONVERT_FROM_BOOLEAN: {
    my $sql_value = 't';
    my $value = sql_convert_from_boolean($sql_value);
    is($value, 1, 'true is 1');

    $sql_value = 'f';
    $value = sql_convert_from_boolean($sql_value);
    is($value, 0, 'false is 0');
}

txn_block: {
    my $val;
#     local $Socialtext::SQL::DEBUG = 1;

    ok get_dbh()->{AutoCommit}, 'not in txn yet';
    is sql_in_transaction(), 0, "no txn";

    sql_txn {
        my @args = @_;
        is_deeply \@args, ['arg one','arg two'], "args get passed in";
        is sql_in_transaction(), 1, "in pure txn";

        sql_execute(
            q{INSERT INTO "System" (field,value) VALUES ('first','ok')});

        ok exception {
            sql_txn {
                is sql_in_transaction(), 2, "two nestings";
                sql_execute(q{INSERT INTO "Barf"});
            };
        }, 'non-existant table causes exception';

        $val = sql_singlevalue(q{
            SELECT value FROM "System" WHERE field = 'first'});
        is $val, 'ok', "savepoint worked";
    } 'arg one', 'arg two';

    is sql_in_transaction(), 0, "no txn";

    {
        package MyTransactionalThing;
        use Moose;
        use Scalar::Util qw/blessed/;
        use Socialtext::SQL qw/:exec :txn/;
        around 'do_a_txn' => \&sql_txn;
        sub do_a_txn {
            my $self = shift;
            my $arg = shift;
            ::ok blessed($self), 'object passed in';
            ::is $arg,'param!', 'arg preserved';
            ::is sql_in_transaction(), 1, "simple txn";
            sql_execute(q{UPDATE "System" SET value='ya' WHERE field='first'});
            die "wtf?";
            sql_execute(q{INSERT INTO "Barf"});
        }
    }
    my $mtt = MyTransactionalThing->new;
    ok exception {
        $mtt->do_a_txn('param!');
    }, 'exception propagates up';

    $val = sql_singlevalue(q{
        SELECT value FROM "System" WHERE field = 'first'});
    is $val, 'ok', "wrapped method txn worked";

    sql_txn {
        is sql_in_transaction(), 1, "in pure txn";
        $val = sql_singlevalue(q{
            SELECT value FROM "System" WHERE field = 'first'});
        is $val, 'ok', "transaction comitted";
        sql_execute(q{DELETE FROM "System" WHERE field = 'first'});
    };

    $val = sql_singlevalue(q{
        SELECT value FROM "System" WHERE field = 'first'});
    is $val, undef, "field removed due to 2nd txn completing";

    my @list = sql_txn { my @q = (5,6); return @q };
    is_deeply \@list, [5,6], "list context ok";

    my $scalar = sql_txn { my @q = (8,9,10); return @q };
    is $scalar, 3, "scalar context ok";
}

dangling_txn: {
    ok !exception {
        sql_begin_work();
        sql_begin_work();
        sql_rollback();
    }, 'two begins, one rollback';
    my @warnings;
    ok !exception {
        local $SIG{__WARN__} = sub {
            push @warnings, $_[0]};
        Socialtext::SQL::disconnect_dbh();
    }, "outside of transaction is not fatal";
    ok @warnings == 2, "got two warnings";
    like $warnings[0], qr/Transaction left dangling/, 'dangling warning';
    like $warnings[1], qr{at t/Socialtext/SQL\.t line \d+ \(.+\)}m,
        'txn stack trace';
}

ensure_temp: {
    my $results = [];
    ok !exception {
        sql_txn {
            eval {
                sql_txn {
                    sql_ensure_temp("my_temp","foo int");
                    die "oh crap";
                };
            };
            ok $@, 'inner transaction got rolled back, cancelling tbl create';
            undef $@;

            sql_ensure_temp("my_temp","foo int");
            sql_execute("INSERT INTO my_temp VALUES (42)");
        };
        my $sth = sql_execute("SELECT * FROM my_temp");
        $results = $sth->fetchall_arrayref;
    }, 'outer transaction is ok';
    is_deeply $results, [[42]];
}

with_local: {
    invalidate_dbh();
    my $addr = refaddr(get_dbh());
    my $pgpid = get_dbh()->{pg_pid};
    with_local_dbh {
        my $addr2 = refaddr(get_dbh());
        isnt $addr, $addr2, "it's local!";
        my $pgpid2 = get_dbh()->{pg_pid};
        isnt $pgpid, $pgpid2, "different pg backend (i.e. conn is unique)";
    };
    my $addr3 = refaddr(get_dbh());
    my $pgpid3 = get_dbh()->{pg_pid};
    is $addr, $addr3, "it didn't get changed!";
    is $pgpid, $pgpid3, "same backend pid";
}

pass 'done';
