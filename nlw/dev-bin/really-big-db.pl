#!/usr/bin/perl
# @COPYRIGHT@
use warnings;
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Socialtext::SQL qw/get_dbh/;
use Socialtext::SQL::Builder qw/sql_nextval/;
use Socialtext::UserSet qw/:const/;
use Socialtext::Account;
use Socialtext::Group;
use Socialtext::Workspace;
use Socialtext::User;
use Socialtext::Role;
use List::Util qw(shuffle);
use Getopt::Long;

my $ACCOUNTS = 200;
my $USERS = 5000; # _Must_ be bigger than $ACCOUNTS - should be more than 10x to get secondary account variations
my $PAGES = 1000;
my $WRITES_PER_COMMIT = 1000;
my $EVENTS = 500_000;
my $GROUPS = 10_000;        # Expected case is "number of groups >= number of users"
my $GROUP_WS_RATIO = 10;        # How many WS's should each Group be added to
my $GROUP_USER_RATIO = 30;      # How many User's should be added to each Group
my $VIEW_EVENT_RATIO = 0.85;
my $SIGNALS = 100_000;

my $now = time;
my $base = substr("$now",-5);

my $member_id = Socialtext::Role->Member->role_id;

GetOptions(
    'accounts|a=i' => \$ACCOUNTS,
    'users|u=i' => \$USERS,
    'pages|p=i' => \$PAGES,
    'events|e=i' => \$EVENTS,
    'groups|g=i' => \$GROUPS,
    'group-ws-ratio=f' => \$GROUP_WS_RATIO,
    'group-user-ratio=f' => \$GROUP_USER_RATIO,
    'view-event-ratio|v=s' => \$VIEW_EVENT_RATIO,
    'signals|s=i' => \$SIGNALS,
    'base|b=s' => \$base,
) or usage();

sub usage {
    die <<EOT
USAGE: $0 [options]

WHERE options are:
  --accounts=N
  --users=N
  --pages=N
  --events=N
  --groups=N
  --group-ws-ratio=F
  --group-user-ratio=F
  --view-event-ratio=F
  --signals=N
  --base=S
EOT
}

my $MAX_WS_ASSIGN = int($ACCOUNTS / 20); 
my $PAGE_VIEW_EVENTS = int($VIEW_EVENT_RATIO * $EVENTS);
my $OTHER_EVENTS = $EVENTS - $PAGE_VIEW_EVENTS;

my $USER_GROUP_ROLES      = int($GROUPS * $GROUP_USER_RATIO);
my $GROUP_WORKSPACE_ROLES = int($GROUPS * $GROUP_WS_RATIO);


my $create_ts = '2007-01-01 00:00:00+0000';
my @accounts;
my %acct_to_uset;
my @workspaces;
my %ws_to_uset;
my @users;
my @groups;
my %ws_to_acct;
my @pages;

my $total_writes = 0;
my $writes = 0;
my $commits = 0;

my $dbh = get_dbh();
$| = 1;

$dbh->{AutoCommit} = 0;
$dbh->rollback;
$dbh->{RaiseError} = 1;

sub maybe_commit {
    return unless $writes >= $WRITES_PER_COMMIT;
    print ".";
    $dbh->commit;

    $total_writes += $writes;
    $commits++;
    $writes = 0;
}
print "USING BASE $base\n";

Socialtext::Account->Default->user_set->_create_insert_temp($dbh, 'bulk');

{
    my %uars;
    sub create_uar {
        my ($user_id, $account_id) = @_;
        unless ($uars{$user_id}{$account_id}++) {
            my $acct = Socialtext::Account->new(account_id => $account_id);
            $acct->user_set->_insert($dbh, $user_id, $account_id, $member_id,
                'bulk');
        }
    }
}

{
    my %gars;
    sub create_gar {
        my ($group_id, $account_id) = @_;
        unless ($gars{$group_id}{$account_id}++) {
            my $acct = Socialtext::Account->new(account_id => $account_id);
            $acct->user_set->_insert($dbh, $group_id, $account_id, $member_id,
                'bulk');
        }
    }
}

{
    print "Creating $ACCOUNTS accounts with $ACCOUNTS workspaces";

    my $acct_sth = $dbh->prepare_cached(qq{
        INSERT INTO "Account" (account_id, name, user_set_id)
        VALUES (?, ?, ?)
    });
    my $ws_sth = $dbh->prepare_cached(qq{
        INSERT INTO "Workspace" (
            workspace_id, name, title, 
            account_id, created_by_user_id, skin_name, user_set_id
        ) VALUES (
            ?, ?, ?,
            ?, 1, 's3', ?
        )
    });

    for (my $i=1; $i<=$ACCOUNTS; $i++) {
        # Create an account
        my $acct_id = sql_nextval('"Account___account_id"');
        my $acct_set_id = $acct_id + ACCT_OFFSET;
        $acct_sth->execute($acct_id, "Test Account $base $i", $acct_set_id);
        push @accounts, $acct_id;

        # Create a workspace
        my $ws_id = sql_nextval('"Workspace___workspace_id"');
        my $ws_set_id = $ws_id + WKSP_OFFSET;
        $ws_sth->execute(
            $ws_id, "test_workspace_${base}_$i", "Test Workspace $base $i",
            $acct_id, $ws_set_id,
        );
        push @workspaces, $ws_id;
        
        $writes += 2;
        $ws_to_acct{$ws_id} = $acct_id;
        $acct_to_uset{$acct_id} = $acct_set_id;
        $ws_to_uset{$ws_id} = $ws_set_id;

        maybe_commit();
    }

    print " done!\n";
}


{
    print "enable people & dashboard & signals for all of the accounts";

    my $pd_sth = $dbh->prepare_cached(qq{
        INSERT INTO user_set_plugin (user_set_id, plugin)
        VALUES (?, ?)
    });

    my $pd_enabled = int(@accounts ); # Assume every account has pd enabled
    foreach my $acct_id (@accounts[0 .. $pd_enabled-1]) {
        for my $plugin ( 'people', 'dashboard', 'widgets', 'signals' ) {
            $pd_sth->execute( $acct_to_uset{$acct_id}, $plugin );
            $writes++;
        }

        maybe_commit();
    }
    print " done!\n";
}

{
    my $n = $ACCOUNTS;
    my $m = $n;
    my $name = $ACCOUNTS;
    my %rand_accounts = map {$_=>1} @accounts;
    
    my $ws_sth = $dbh->prepare_cached(qq{
        INSERT INTO "Workspace" (
            workspace_id, name, title, 
            account_id, created_by_user_id, skin_name, user_set_id
        ) VALUES (
            ?, ?, ?,
            ?, 1, 's3', ?
        )
    });

    print "Assigning $ACCOUNTS more workspaces to random accounts (geometric dist.)";
    while ($n > 0) {
        $m = int($n / 2.0);
        $m = 1 if $m <= 0;

        # pick an account at random
        # assign M workspaces to it
        my $acct_id = (keys %rand_accounts)[0];
        delete $rand_accounts{$acct_id};

        for (my $j=0; $j<$m; $j++) {
            $name++;
            my $ws_id = sql_nextval('"Workspace___workspace_id"');
            $ws_sth->execute($ws_id, "test_workspace_${base}_$name",
                "Test Workspace $base $name", $acct_id, $ws_id + WKSP_OFFSET);
            $writes++;
            push @workspaces, $ws_id;
            $ws_to_acct{$ws_id} = $acct_id;
            maybe_commit();
        }

        $n -= $m;
    }
    print " done!\n";
}

{
    print "Adding $USERS users";

    my $user_sth = $dbh->prepare_cached(qq{
        INSERT INTO users (
            user_id, driver_unique_id, driver_key, driver_username,
            email_address, password, first_name, last_name, display_name
        ) VALUES (
            nextval('users___user_id'), currval('users___user_id'), ?, ?,
            ?, ?, ?, ?, ?
        )
    });

    my $user_meta_sth = $dbh->prepare_cached(qq{
        INSERT INTO "UserMetadata" (
           user_id, email_address_at_import, 
           created_by_user_id, primary_account_id
        ) VALUES (
           currval('users___user_id'), ?, NULL, ?
        )
    });

    for (my $user=1; $user<=$USERS; $user++) {
        my $uname = "user-$user-$base\@ken.socialtext.net";
        warn "Creating $uname";
        # salted hash for 'password' as password 
        $user_sth->execute('Default', $uname, $uname, "sa3tHJ3/KuYvI",
            "First$user", "Last$user", "First$user Last$user");
        warn "inserting meta";

        # choose a random primary account id
        my $priacctid = $accounts[rand(@accounts)];
        $user_meta_sth->execute( $uname, $priacctid );

        warn "Getting user_id";
        my ($user_id) = $dbh->selectrow_array(q{SELECT currval('users___user_id')});
        warn "Creating uar";
        create_uar( $user_id, $priacctid );

        push @users, $user_id;
        $writes += 3;
        maybe_commit();
    }
    print " done!\n";
}

{
    print "Assigning users to accounts and workspaces";

    my $updt_sth = $dbh->prepare_cached(q{
        UPDATE "UserMetadata"
        SET primary_account_id = ?
        WHERE user_id = ?
    });
    sub assign_random_workspaces {
        my ($user_id, $number, $workspaces) = @_;
        my %done;
        warn "assign_random_workspaces to $user_id ($number)";

        my $primary_ws = $workspaces[int(rand(@$workspaces))];
        $updt_sth->execute($ws_to_acct{$primary_ws}, $user_id);
        my $ws = Socialtext::Workspace->new(workspace_id => $primary_ws);
        $ws->user_set->_insert($dbh, $user_id, $primary_ws, $member_id,
            'bulk');
        create_uar($user_id, $ws_to_acct{$primary_ws});
        $writes += 3;
        $done{$primary_ws} = 1;

        my $assigned = 1;
        # put an upper-bound on the guess-and-check method of randomly
        # assigning workspaces
        my $max = int(1.5 * $number);
        for (my $i=0; $i<$max; $i++) {
            my $ws_id = $workspaces[int(rand(@$workspaces))];
            next if $done{$ws_id};

            # assign a user to a workspace
            my $ws = Socialtext::Workspace->new(workspace_id => $ws_id);
            $ws->user_set->_insert($dbh, $user_id, $ws_id, $member_id,
                'bulk');
            create_uar($user_id, $ws_to_acct{$ws_id});
            $writes += 2;
            $done{$ws_id} = 1;
            last if keys(%done) >= $number;
        }
        maybe_commit();
    }

    # assigns half of the users to some number of workspaces
    my %rand_users = map { $_ => 1 } @users;
    for (my $i=1; $i<=$USERS/2; $i++) {
        my $m = int(rand($MAX_WS_ASSIGN))+1;
        my $user_id = (keys %rand_users)[0];
        delete $rand_users{$user_id};
        assign_random_workspaces($user_id, $m, \@workspaces); 
    }

    print " done!\n";
}

{
    print "Adding $GROUPS groups";
    my $create_group_sth = $dbh->prepare_cached(qq{
        INSERT INTO groups (
            group_id, driver_unique_id,
            driver_key, driver_group_name,
            primary_account_id, created_by_user_id
        ) VALUES (
            nextval('groups___group_id'), currval('groups___group_id'),
            ?, ?, ?, ?
        );
    } );

    for (my $group=1; $group<=$GROUPS; $group++) {
        # pick random User to create the Group
        my $user = $users[ rand(@users) ];

        # get the User's primary account
        my ($account) = $dbh->selectrow_array(q{
            SELECT primary_account_id FROM "UserMetadata" WHERE user_id=?
        }, {}, $user);

        # create the Group
        my $group_name = "group-$group-$base";
        $create_group_sth->execute('Default', $group_name, $account, $user);

        # re-query the Group's group_id
        my ($group_id) = $dbh->selectrow_array(q{
            SELECT currval('groups___group_id')
        });
        create_gar( $group_id, $account );

        push @groups, $group_id;
        $writes += 2;
        maybe_commit();
    }
    print " done!\n";
}

{
    print "Assigning $USER_GROUP_ROLES User->Group Roles";
    my %available;

    for (0 .. $USER_GROUP_ROLES) {
        # pick a random Group
        my $group_id = $groups[ rand(@groups) ];
        last unless defined $group_id;

        # pick a random User (that isn't in the Group yet)
        unless (exists $available{$group_id}) {
            $available{$group_id} = [ @users ];
        }

        my $offset  = rand( @{$available{$group_id}} );
        my $user_id = splice( @{$available{$group_id}}, $offset, 1 );

        # give the User a Role in this Group
        if ($user_id) {
            my $group = Socialtext::Group->GetGroup(group_id => $group_id);
            $group->user_set->_insert($dbh, $user_id, $group_id, $member_id,
                'bulk');
            $writes++;
            maybe_commit();
        }
    }
    print " done!\n";
}

{
    print "Assigning $GROUP_WORKSPACE_ROLES Group->Workspace Roles";
    my %available;

    for (0 .. $GROUP_WORKSPACE_ROLES) {
        # pick a random Group
        my $group_id = $groups[ rand(@groups) ];
        last unless defined $group_id;

        # pick random WS (that the Group isn't in yet)
        unless (exists $available{$group_id}) {
            $available{$group_id} = [ @workspaces ];
        }

        my $offset = rand( @{$available{$group_id}} );
        my $ws_id  = splice( @{$available{$group_id}}, $offset, 1 );

        # give the Group a Role in this Workspace
        if ($ws_id) {
            my $ws = Socialtext::Workspace->new(workspace_id => $ws_id);
            $ws->user_set->_insert($dbh, $group_id, $ws_id, $member_id,
                'bulk');

            create_gar( $group_id, $ws_to_acct{$ws_id} );
            $writes += 2;
            maybe_commit();
        }
    }
    print " done!\n";
}

print "CHECK >>> system-wide users with the default account: ";
print $dbh->selectrow_array('select count(*) from "UserMetadata" where primary_account_id = 1');
print "\n";

{
    print "creating $PAGES pages";
    my $page_sth = $dbh->prepare_cached(q{
        INSERT INTO page (
            workspace_id, page_id, name, 
            last_editor_id, creator_id,
            last_edit_time, create_time,
            current_revision_id, current_revision_num, revision_count,
            page_type, deleted, summary
        ) VALUES (
            ?, ?, ?,
            ?, ?,
            ?::timestamptz + ?::interval, ?::timestamptz,
            ?, 1, 1,
            'wiki', 'f', 'summary'
        )
    });

    for (my $p=1; $p<=$PAGES; $p++) {
        my $ws = $workspaces[int(rand(scalar @workspaces))];
        my $editor = $users[int(rand(scalar @users))];
        my $creator = $users[int(rand(scalar @users))];
        my $page_id = "page_${base}_$p";
        $page_sth->execute(
            $ws, $page_id, "Page: $base $p!",
            $editor, $creator,
            $create_ts, rand(int($PAGES)).' seconds', $create_ts,
            '20070101000000',
        );
        $writes++;
        maybe_commit();
        push @pages, [$ws, $page_id];
    }
    print " done!\n";
}

{
    print "generating $PAGE_VIEW_EVENTS page view events";

    my $ev_sth = $dbh->prepare_cached(q{
        INSERT INTO event (
            at, event_class, action, 
            actor_id, page_workspace_id, page_id
        ) VALUES (
            ?::timestamptz + ?::interval, 'page', 'view', 
            ?, ?, ?
        )
    });
    for (my $i=0; $i<$PAGE_VIEW_EVENTS; $i++) {
        my $actor = $users[int(rand(scalar @users))];
        my $page = $pages[int(rand(scalar @pages))];
        $ev_sth->execute(
            $create_ts, sprintf('%0.6f', rand($PAGES)).' seconds', 
            $actor, $page->[0], $page->[1]
        );
        $writes++;
        maybe_commit();
    }
    print " done!\n";
}

{
    print "generating $OTHER_EVENTS other events";
    my $ev_sth = $dbh->prepare_cached(q{
        INSERT INTO event (
            at, 
            event_class, action, 
            actor_id, person_id, page_workspace_id, page_id
        ) VALUES (
            ?::timestamptz + ?::interval,
            ?, ?, 
            ?, ?, ?, ?
        )
    });

    for (my $i=0; $i<$OTHER_EVENTS; $i++) {
        my $actor = $users[int(rand(scalar @users))];
        my $page = [undef,undef];
        my $person = undef;
        my @actions;

        my @classes = (('page') x 8, 'person');
        my $class = $classes[int(rand(scalar @classes))];
        if ($class eq 'page') {
            $page = $pages[int(rand(scalar @pages))];
            @actions = qw(tag_add watch_add watch_delete rename edit_save comment duplicate tag_delete delete);
        }
        else {
            $person = $users[int(rand(scalar @users))];
            @actions = qw(tag_add watch_add tag_delete watch_delete edit_save);
        }
        my $action = $actions[int(rand(scalar @actions))];

        $ev_sth->execute(
            $create_ts, rand(int($PAGES)).' seconds', 
            $class, $action,
            $actor, $person, $page->[0], $page->[1]
        );
        $writes++;
        maybe_commit();
    }
    print " done!\n";
}
print "CHECK >>> system-wide page view events: ";
print $dbh->selectrow_array(q{select count(*) from event where event_class = 'page' and action = 'view'});
print "\n";

print "CHECK >>> system-wide non-page view events: ";
print $dbh->selectrow_array(q{select count(*) from event where not (event_class = 'page' and action = 'view')});
print "\n";

print "CHECK >>> page events with null page_id (should be zero): ";
print $dbh->selectrow_array(q{select count(*) from event where event_class='page' AND page_id IS NULL});
print "\n";

{
    print "Generating $SIGNALS signals";

    print "\n\tGetting accounts for each created users";
    my %useraccounts = ();
    my @signalusers = ();
    my $ua_sth= $dbh->prepare_cached(q{
        SELECT DISTINCT(into_set_id) - }.PG_ACCT_OFFSET.q{ 
          FROM user_set_path path
          JOIN user_set_plugin plug ON (path.into_set_id = plug.user_set_id)
         WHERE plugin = 'signals'
           AND from_set_id = ?
        });

    for (my $user=1; $user<=$USERS; $user++) {
        my @accountids=();
        my $rc = $ua_sth->execute($user);
        my $results = $ua_sth->fetchall_arrayref();
        foreach (@$results) {
            push(@accountids, $_->[0]);
        }
        if (@$results) {
            $useraccounts{$user}=\@accountids;
            push (@signalusers, $user);
        }
    }
    print " done!\n";
    my $sig_sth = $dbh->prepare_cached(q{
        INSERT INTO signal (signal_id, user_id, body, at) 
        VALUES (nextval('signal_id_seq'), ?, ?, 'now'::timestamptz + ?::interval)
    });

    my $ev_sth = $dbh->prepare_cached(q{
        INSERT INTO event (
            at,
            event_class, action,
            actor_id, person_id, page_workspace_id, page_id, signal_id
        ) VALUES (
            ?::timestamptz + ?::interval,
            ?, ?, ?, ?, ?, ?, currval('signal_id_seq')
        )
    });

    my $topic_sth = $dbh->prepare_cached(q{
        INSERT INTO topic_signal_page (signal_id, workspace_id, page_id) 
        VALUES (currval('signal_id_seq'), ?, ?)
    });


    my $account_signal_sth = $dbh->prepare_cached(q{
        INSERT INTO signal_account (signal_id, account_id)
        VALUES (currval('signal_id_seq'), ?)
        });

    for ( my $i = 0; $i < $SIGNALS; $i++ ) {
        my $is_page_edit = (rand(10) < 2 || 0);
        my $user         = $signalusers[int(rand(scalar @signalusers))];
        my $page         = $pages[int(rand(scalar @pages))];
        my $action       = ( $is_page_edit ) ? 'edit_save' : 'signal';
        my $interval     = rand(int($SIGNALS)).' seconds';

        $sig_sth->execute($user, "signal $i $is_page_edit", $interval);
        $writes++;

        if ($is_page_edit) {
            $topic_sth->execute($page->[0], $page->[1]);
            $writes++;
            $account_signal_sth->execute($ws_to_acct{$page->[0]});
            $writes++;
        }
        else {
            $ev_sth->execute(
                $create_ts, $interval,
                'signal', $action,    $user,
                $user,    $page->[0], $page->[1]
            );
            $writes++;
            my $accounts = $useraccounts{$user};
            # Select a random (1-n) list of accounts belonging to the posting user
            my @shuffled = shuffle @{$accounts};
            my $numaccounts = int(rand(scalar(@shuffled)))+1; # 1 to $#shuffled
            my @signaled_accounts = @shuffled[0..($numaccounts-1)];
            foreach (@signaled_accounts) {
                $account_signal_sth->execute($_);
                $writes++
            }
        }

        maybe_commit();
    }

    print " done!\n";
}

print "CHECK >>> system-wide signals: ";
print $dbh->selectrow_array(q{select count(*) from signal});
print "\n";

print "CHECK >>> signal events with null signal_id (should be zero): ";
print $dbh->selectrow_array(q{select count(*) from event where event_class='signal' AND signal_id IS NULL});
print "\n";

# page tags?
# people tags?

# page watchlists
# people watchlists

$commits++;
$total_writes += $writes;
$dbh->commit;

print "ALL DONE ($total_writes writes, $commits commits)!\n";
