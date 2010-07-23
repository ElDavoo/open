# @COPYRIGHT@
package Socialtext::SQL;
use strict;
use Socialtext::Date;
use Socialtext::AppConfig;
use Socialtext::Timer;
use DateTime::Format::Pg;
use DBI;
use Scalar::Util qw/blessed/;
use Carp qw/confess carp croak cluck/;
use List::MoreUtils qw/any/;
use base 'Exporter';

=head1 NAME

Socialtext::SQL - wrapper interface around SQL methods

=head1 SYNOPSIS

  use Socialtext::SQL qw/:exec :txn/;

  # Regular, auto-commit style:
  my $sth = sql_execute( $SQL, @BIND );
   
  # DIY commit:
  sql_begin_work();
  eval { sql_execute( $SQL, @BIND ) };
  if ($@) {
      sql_roll_back();
  }
  else {
      sql_commit();
  }

=head1 DESCRIPTION

Provides methods with extra error checking and connections to the database.

=cut

our @EXPORT_OK = qw(
    get_dbh disconnect_dbh invalidate_dbh
    sql_execute sql_execute_array sql_selectrow sql_singlevalue 
    sql_commit sql_begin_work sql_rollback sql_in_transaction
    sql_txn
    sql_convert_to_boolean sql_convert_from_boolean
    sql_parse_timestamptz sql_format_timestamptz sql_timestamptz_now
    sql_ensure_temp
);
our %EXPORT_TAGS = (
    'exec' => [qw(sql_execute sql_execute_array
                  sql_selectrow sql_singlevalue)],
    'time' => [qw(sql_parse_timestamptz sql_format_timestamptz 
                  sql_timestamptz_now)],
    'bool' => [qw(sql_convert_to_boolean sql_convert_from_boolean)],
    'txn'  => [qw(sql_txn sql_commit sql_begin_work
                  sql_rollback sql_in_transaction)],
);


our $DEBUG = 0;
our $TRACE_SQL = 0;
our $PROFILE_SQL = 0;
our $COUNT_SQL = 0;
our $Level = 2;

protect_the_dbh: {
    my $DBH;
    my $NEEDS_PING = 1;

=head1 Connection

=head2 get_dbh()

Returns a raw C<DBI> handle to the database.  The connection will be cached.

When forking a new process be sure to, C<disconnect_dbh()> first.

=cut

    sub get_dbh {
        if ($DBH && !$NEEDS_PING) {
            warn "Returning cached connection" if $DEBUG;
            return $DBH
        }

        Socialtext::Timer->Continue('get_dbh');
        eval {
            if (!$DBH) {
                warn "No connection" if $DEBUG;
                _connect_dbh();
            }
            elsif ($NEEDS_PING && !$DBH->ping()) {
                warn "dbh ping failed\n";
                disconnect_dbh();
                _connect_dbh();
            }
        };
        my $err = $@;
        Socialtext::Timer->Pause('get_dbh');

        croak $err if $@;
        return $DBH;
    }

    sub _connect_dbh {
        cluck "Creating a new DBH" if $DEBUG;
        my %params = Socialtext::AppConfig->db_connect_params();
        my $dsn = "dbi:Pg:database=$params{db_name}";

        $DBH = DBI->connect($dsn, $params{user}, "",  {
                AutoCommit => 1,
                pg_enable_utf8 => 1,
                PrintError => 0,
                RaiseError => 0,
            });

        die "Could not connect to database with dsn: $dsn: $!\n" unless $DBH;

        $DBH->do("SET client_min_messages TO 'WARNING'");
        $DBH->{'private_Socialtext::SQL'} = {
            txn_stack => [],
            temps => {},
        };

        $NEEDS_PING = 0;
    }

=head2 disconnect_dbh

Forces the DBI connection to close.  Useful for scripts to avoid deadlocks.

=cut

    sub disconnect_dbh {
        warn "Disconnecting dbh" if $DEBUG;
        if ($DBH && !$DBH->{AutoCommit}) {
            carp "WARNING: Transaction left dangling at disconnect";
            _dump_txn_stack($DBH);
        }
        $DBH->disconnect if $DBH;
        undef $DBH;
        undef $NEEDS_PING;
        return;
    }

=head2 invalidate_dbh

Make the next call to C<get_dbh()> ping the database and rollback any
outstanding transaction(s).  If the ping fails, a reconnect will occur.  This
should be used before sleeping or entering a blocking-wait state (e.g. at
apache request boundaries)

=cut

    sub invalidate_dbh {
        warn "Invalidating dbh" if $DEBUG;
        if ($DBH && !$DBH->{AutoCommit}) {
            carp "WARNING: Transaction left dangling at end of request, ".
                 "rolling back";
            _dump_txn_stack($DBH);
            $DBH->rollback();
        }
        $NEEDS_PING = 1
    }
}

=head1 Transactions

Nested transactions are now supported through the use of postgres savepoints.

L<http://www.postgresql.org/docs/8.1/static/sql-savepoint.html>

Use C<sql_txn> unless you need to do something fancy; it's much less
error-prone than matching up begin/commit/rollback commands manually.

Both C<sql_txn> and C<sql_begin_work> are interoperable.  It's safe to use
C<sql_txn> between C<sql_begin_work> and C<sql_commit> calls.  3rd-party code
that starts transactions via C<< $dbh->begin_work >> is not supported.

=head2 sql_txn { run_stuff };

Run a block of code in a transaction (or use a savepoint if one's already
started).  If the code dies, the transaction (or savepoint) is rolled back.
Upon success, the transaction is committed (or the savepoint released).

It's safe to call C<sql_begin_work> and other transaction funcions from with
the code closure.

    sub foo {
        sql_begin_work();
        eval { ... };
        $@ ? sql_rollback() : sql_commit();
    }
    sub bar {
        sql_txn {
            foo();
        };
    }

The calling context (C<wantarray>) and calling parameters are preserved.  This
allows you to use this sub as a C<Moose> or C<Class::MOP> method wrapper:

    around 'baz' => \&sql_txn;
    sub baz {
        my $self = shift;
        #...
        die 'this will cause a rollback' if $failed;
        return 'woot';
    }

When not using Moose, remember to pass through any arguments you aren't
closing-over in the transaction block.

    sub my_wrapper {
        my $self = shift;
        my $x = shift;
        # do stuff outside of txn
        return sql_txn {
            my $y = shift;
            do_stuff($x,$y,@_);
        }, @_; # pass in @_ to make shift do the right thing
    }

=cut

sub sql_txn (&;@) {
    my $code = shift;

    sql_begin_work([caller()]);

    # the following is based on code from Try::Tiny:
    my $wa = wantarray;
    my @rv;
    my $e;
    {
        local $@; # preserve $@ outside of this call
        eval {
            if ($wa) { # call in list context
                @rv = $code->(@_);
            }
            elsif (defined $wa) { # call in scalar context
                $rv[0] = $code->(@_);
            }
            else { # call in void context
                $code->(@_);
            }
            return 1; # successful call
        };
        $e = $@; # copy back out due to local $@
    }

    if ($e) {
        carp "sql_txn rollback..." if $DEBUG;
        eval { sql_rollback() };
        $e .= "\nand during rollback: $@" if ($@ && !blessed($e));
        $@ = $e; # make Test::Exception happy
        die $e;
    }
    else {
        carp "sql_txn committing..." if $DEBUG;
        sql_commit();
    }

    return unless defined $wa;
    return $wa ? @rv : $rv[0];
}

=head2 sql_in_transaction()

Returns 0 if not in a transaction.  Returns the transaction "level" otherwise.
1 means a pure transaction, 2 and above indicate savepoints are in use.

=head2 sql_begin_work()

Starts a transaction or creates a savepoint. Using C<sql_txn> is recomended,
however.  Dies if a transaction/savepoint couldn't be started.

=head2 sql_commit()

Commit a transaction or release the most recent savepoint.  Dies on failure to
do so.

=head2 sql_rollback()

Rollback a transaction or to the most recent savepoint. Dies on failure to do
so.

=cut

sub sql_in_transaction {
    my $dbh = get_dbh();
    return 0 if $dbh->{AutoCommit};
    return scalar(@{$dbh->{'private_Socialtext::SQL'}{txn_stack}})||1;
}

my $savepoint = 0;
sub sql_begin_work {
    my $dbh = get_dbh();
    my $caller = shift || [caller];

    my $sp = 0;
    if ($dbh->{AutoCommit}) {
        carp "Beginning transaction" if $DEBUG;
    }
    else {
        $sp = "st_".$savepoint++;
        if ($DEBUG) {
            carp "Creating savepoint $sp, ".
                 "level ".(1+@{$dbh->{'private_Socialtext::SQL'}{txn_stack}});
        }
    }

    local $dbh->{RaiseError} = 1;
    push @{$dbh->{'private_Socialtext::SQL'}{txn_stack}}, [$sp,@$caller];
    return $sp ? $dbh->pg_savepoint($sp) : $dbh->begin_work();
}

sub sql_commit {
    my $dbh = get_dbh();
    if ($dbh->{AutoCommit}) {
        carp "commit while outside of transaction";
        return;
    }

    local $dbh->{RaiseError} = 1;
    my $rec = pop @{$dbh->{'private_Socialtext::SQL'}{txn_stack}};
    if ($rec->[0]) {
        carp "Releasing savepoint $rec->[0]" if $DEBUG;
        return $dbh->pg_release($rec->[0]);
    }
    else {
        carp "Committing transaction" if $DEBUG;
        return $dbh->commit();
    }
}

sub sql_rollback {
    my $dbh = get_dbh();
    if ($dbh->{AutoCommit}) {
        carp "rollback while outside of transaction";
        return;
    }

    local $dbh->{RaiseError} = 1;
    my $rec = pop @{$dbh->{'private_Socialtext::SQL'}{txn_stack}};
    if ($rec->[0]) {
        carp "Rolling back to savepoint $rec->[0]" if $DEBUG;
        return $dbh->pg_rollback_to($rec->[0]);
    }
    else {
        carp "Rolling back transaction" if $DEBUG;
        return $dbh->rollback();
    }
}

sub _dump_txn_stack {
    my $dbh = shift;
    my @w = ("Transaction stack:\n");
    my $stack = $dbh->{'private_Socialtext::SQL'}{txn_stack};
    foreach my $caller (@$stack) {
        push @w, "\tat $caller->[2] line $caller->[3] ($caller->[1])\n";
    }
    warn join('',@w); # so as to just call 'warn' once
    @$stack = ();
}

=head1 Querying

=head2 sql_execute( $SQL, @BIND )

sql_execute() will wrap the execution in a begin/commit block
UNLESS the caller has already set up a transaction

Returns a statement handle.

=cut

sub sql_execute {
    my $statement = shift;
    # rest of @_ are bindings, prevent making copies
    my $bind = \@_;

    my $sth;
    eval { $sth = _sql_execute($statement, 'execute', $bind) };

    if (my $err = $@) {
        my $msg = "Error during sql_execute():\n$statement\n";
        $msg .= _list_bindings($bind);
        confess "${msg}Error: $err";
    }
    return $sth;
}

=head2 sql_execute_array( $SQL, @BIND )

Like sql_execute(), but pass in an array of array of bind values.

=cut

sub sql_execute_array {
    my $statement = shift;
    my $opts = shift;
    # rest of @_ are bindings, prevent making copies
    my $bind = \@_;

    my @status;
    $opts->{ArrayTupleStatus} = \@status;
    unshift @$bind, $opts;

    my $sth;
    eval { $sth = _sql_execute($statement, 'execute_array', $bind) };

    if ($@) {
        my $msg = "Error during sql_execute():\n$statement\n";
        $msg .= _list_bindings($bind);
        my %dups;
        my @errors = map { $_->[1] }
                    grep { ref $_ and !$dups{$_->[1]}++ }
                         @status;
        my $err = join("\n", @errors);
        croak "${msg}\nErrors: $@\n$err\n";
    }
    return $sth;
}

sub _sql_execute {
    my ($statement, $exec_sub, $bind) = @_;

    my $dbh = get_dbh();
    Socialtext::Timer->Continue('sql_execute');

    my ($sth, $rv);
    if ($DEBUG or $TRACE_SQL) {
        my (undef, $file, $line) = caller($Level);
        warn "Preparing ($statement) "
            . _list_bindings($bind)
            . " from $file line $line\n";
    }
    if ($PROFILE_SQL && $statement =~ /^\W*SELECT/i) {
        my (undef, $file, $line) = caller($Level);
        my $explain = "EXPLAIN ANALYZE $statement";
        my $esth = $dbh->prepare($explain);
        $esth->$exec_sub(@$bind);
        my $lines = $esth->fetchall_arrayref();
        warn "Profiling ($statement) "
            . _list_bindings($bind)
            . " from $file line $line\n"
            . join('', map { "$_->[0]\n" } @$lines);
    }

    eval {
        _count_sql($statement) if $COUNT_SQL;
        Socialtext::Timer->Continue('sql_prepare');
        $sth = $dbh->prepare($statement);
        Socialtext::Timer->Pause('sql_prepare');
        $sth->$exec_sub(@$bind)
            || die "$exec_sub failed: " . $sth->errstr . "\n";
    };

    if (my $err = $@) {
        Socialtext::Timer->Pause('sql_execute');
        die "$@\n";
    }

    Socialtext::Timer->Pause('sql_execute');
    return $sth;
}

sub _count_sql {
    my $sql = shift;
    $sql =~ s/\s+/ /sm;
    $sql =~ s/\n/ /smg;

    require Digest::SHA1;
    my $sql_file = '/tmp/sql-count';
    open(my $fh, ">>$sql_file") or die "Can't open $sql_file: $!";
    print $fh Digest::SHA1::sha1_hex($sql), " $sql\n";
    close $fh;
}

sub _list_bindings {
    my $bindings = shift;
    return 'bindings=('
         . join(',', map { defined $_ ? "'$_'" : 'NULL' } @$bindings)
         . ')';
}

=head2 sql_selectrow( $SQL, @BIND )

Wrapper around $sth->selectrow_array 

=cut

sub sql_selectrow {
    my ( $statement, @bindings ) = @_;

    Socialtext::Timer->Continue('sql_selectrow');
    my @result = get_dbh->selectrow_array($statement, undef, @bindings);
    Socialtext::Timer->Pause('sql_selectrow');
    return @result;
}

=head2 sql_singlevalue( $SQL, @BIND )

Wrapper around returning a single value from a query.

=cut

sub sql_singlevalue {
    my ( $statement, @bindings ) = @_;

    local $Level = $Level + 1;
    my $sth = sql_execute($statement, @bindings);
    my $value;
    $sth->bind_columns(undef, \$value);
    $sth->fetch();
    $sth->finish();
    $value =~ s/\s+$// if defined $value;
    return $value;
}

=head1 Utility

=head2 sql_convert_to_boolean()

Perl true-false to sql boolean.

=cut

sub sql_convert_to_boolean {
    my $value= shift;
    my $default = shift;

    return $default if (!defined($value));
    return $value ? 't' : 'f';
}

=head2 sql_convert_from_boolean()

Maps SQL t/f to perl true-false.

=cut

sub sql_convert_from_boolean {
    my $value= shift;

    return $value eq 't' ? 1 : 0;
}

=head2 sql_parse_timestamptz()

Parses a timestamptz column into a DateTime object (technically it's a
DateTime::Format::Pg)

=cut

sub sql_parse_timestamptz {
    my $value = shift;
    return DateTime::Format::Pg->parse_timestamptz($value);
}

=head2 sql_format_timestamptz()

Converts a DateTime object into a timestamptz column format.

=cut

sub sql_format_timestamptz {
    my $dt = shift;
    my $fmt = DateTime::Format::Pg->format_timestamptz($dt);
    if (!$dt->is_finite) {
        # work around a DateTime::Format::Pg bug
        $fmt =~ s/infinite$/infinity/g;
    }
    return $fmt;
}


=head2 sql_timestamptz_now()

Return the current time as a hires, formatted, timestamptz string.

=cut

sub sql_timestamptz_now {
    return sql_format_timestamptz(Socialtext::Date->now(hires=>1));
}

=head2 sql_ensure_temp($table, $defn, [@indexes])

Ensure that a temporary table is set up for this connection. The column
definitions are passed in as C<$defn>, and should be valid SQL for the
"inside" of a CREATE TABLE statement.  Basically:

  CREATE TEMPORARY TABLE $table ( $defn ) ON COMMIT PRESERVE ROWS;

If you need indexes applied, pass those CREATE INDEX statements in full as
subsequent parameters.

If the temp table already exists it's truncated and the indexes aren't
reapplied.

=cut

sub sql_ensure_temp {
    my ($table, $defn, @idx) = @_;
    if (any { $_=~/;/ } $table, $defn, @idx) {
        croak "temp table, its definition, and its indexes cannot contain ';'";
    }

    my $dbh = get_dbh();
    if ($dbh->state && $dbh->state !~ /^0[012]/) {
        carp "skipping creating temp table; in error state anyway ".$dbh->state;
        return;
    }

    my $needs_create = 0;

    eval {
        sql_txn {
            local $dbh->{RaiseError} = 0;
            carp "TRUNCATE-ing $table" if ($PROFILE_SQL||$TRACE_SQL||$DEBUG);
            $dbh->do(qq{TRUNCATE $table});
            my $st = $dbh->state;
            carp "TRUNCATE status: $st" if $DEBUG;
            $needs_create = 1 if ($st eq '42P01'); # UNDEFINED TABLE
            die $dbh->errstr if $dbh->errstr;
        };
    };
    die $@ if ($@ && !$needs_create);

    return unless $needs_create;
    sql_txn {
        carp "Creating temp '$table'" if ($PROFILE_SQL||$TRACE_SQL||$DEBUG);
        my $sql = qq{CREATE TEMPORARY TABLE $table ( $defn )
                     WITHOUT OIDS ON COMMIT PRESERVE ROWS};
        sql_execute($sql);
        for my $idx (@idx) {
            sql_execute($idx);
        }
    };
}

1;
