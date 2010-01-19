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
use Socialtext::List qw/rand_subset rand_pick/;
use Getopt::Long;

my $ACCOUNTS = 200;
my $USERS = 5000; # _Must_ be bigger than $ACCOUNTS - should be more than 10x to get secondary account variations
my $PAGES = 1000;
my $WRITES_PER_COMMIT = 1000;
my $EVENTS = 500_000;
my $GROUPS = 10_000;        # Expected case is "number of groups >= number of users"
my $GROUP_WS_RATIO = 10;    # workspaces per group, on avg (+/- 50%)
my $GROUP_USER_RATIO = 30;  # users per group on avg (+/- 50%)
my $VIEW_EVENT_RATIO = 0.85;
my $SIGNALS = 100_000;
my $SIG_BROADCAST_RATIO = 0.90; # percent of signals that are broadcasts

my $now = time;
my $base = substr("$now",-5);

my $member_id = Socialtext::Role->Member->role_id;
my $admin_id = Socialtext::Role->Admin->role_id;

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
my $MAX_ACCT_ASSIGN = int($ACCOUNTS / 200); 
my $PAGE_VIEW_EVENTS = int($VIEW_EVENT_RATIO * $EVENTS);
my $OTHER_EVENTS = $EVENTS - $PAGE_VIEW_EVENTS;


my $create_ts = '2007-01-01 00:00:00+0000';
my @accounts;
my %acct_to_uset;
my @workspaces;
my %ws_to_uset;
my @users;
my @groups;
my %ws_to_acct;
my @pages;
my %user_to_pri_acct;

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

{
    my $aus = Socialtext::UserSet->new();
    $aus->_create_insert_temp($dbh,'bulk');
    sub insert_role {
        my ($from_set_id, $into_set_id, $role_id) = @_;
        $aus->_insert($dbh, $from_set_id, $into_set_id, $role_id, 'bulk');
        $writes++;
    }
}

my %uars;
sub create_uar {
    my ($user_id, $account_id) = @_;
    unless ($uars{$user_id}{$account_id}++) {
        insert_role($user_id, $account_id + ACCT_OFFSET, $member_id);
    }
}

my %gars;
sub create_gar {
    my ($group_id, $account_id) = @_;
    unless ($gars{$group_id}{$account_id}++) {
        insert_role($group_id + GROUP_OFFSET,
                    $account_id + ACCT_OFFSET, $member_id);
    }
}

my %ugrs;
sub create_ugr {
    my ($user_id, $group_id, $role_id) = @_;
    $role_id ||= $member_id;
    unless ($ugrs{$group_id}{$user_id}++) {
        insert_role($user_id, $group_id + GROUP_OFFSET, $role_id);
    }
}

my %uwrs;
sub create_uwr {
    my ($user_id, $ws_id) = @_;
    unless ($uwrs{$ws_id}{$user_id}++) {
        insert_role($user_id, $ws_id + WKSP_OFFSET, $member_id);
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
    my @rand_accounts = shuffle @accounts;
    
    my $ws_sth = $dbh->prepare_cached(qq{
        INSERT INTO "Workspace" (
            workspace_id, name, title, 
            account_id, created_by_user_id, skin_name, user_set_id
        ) VALUES (
            ?, ?, ?,
            ?, 1, 's3', ?
        )
    });

    print "Assigning $ACCOUNTS more workspaces to random accounts (geometric dist.)\n";
    while ($n > 0) {
        $m = int($n / 2.0);
        $m = 1 if $m <= 0;

        my $acct_id = shift @rand_accounts;

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
        # salted hash for 'password' as password 
        $user_sth->execute('Default', $uname, $uname, "sa3tHJ3/KuYvI",
            "First$user", "Last$user", "First$user Last$user");
        $writes++;

        # choose a random primary account id
        my $priacctid = rand_pick @accounts;
        $user_meta_sth->execute( $uname, $priacctid );
        $writes++;

        my ($user_id) = $dbh->selectrow_array(q{SELECT currval('users___user_id')});
        create_uar($user_id, $priacctid);
        $user_to_pri_acct{$user_id} = $priacctid;

        push @users, $user_id;
        maybe_commit();
    }
    print "\n done!\n";
}

{
    print "Assigning users to workspaces";

    # assigns half of the users to some number of workspaces
    my @rand_users = rand_subset @users, $USERS/2;
    my $m = int(rand($MAX_WS_ASSIGN))+1;
    for my $user_id (@rand_users) {
        my @ws_ids = rand_subset @workspaces, $m;
        for my $ws_id (@ws_ids) {
            create_uwr($user_id, $ws_id);
        }
        maybe_commit();
    }

    print " done!\n";
}

{
    print "Assigning users to accounts";

    # assigns a third of the users to some number of accounts
    my @rand_users = rand_subset @users, $USERS/3;
    for my $user_id (@rand_users) {
        my $m = rand($MAX_ACCT_ASSIGN)+1;
        for my $acct_id (rand_subset @accounts, $m) {
            create_uar($user_id, $acct_id);
        }
        maybe_commit();
    }

    print " done!\n";
}

{
    print "Adding $GROUPS groups";
    my $create_group_sth = $dbh->prepare_cached(q{
        INSERT INTO groups (
            group_id, driver_unique_id, user_set_id,
            driver_key, driver_group_name,
            primary_account_id, created_by_user_id
        ) VALUES (
            $1::bigint, $1::text, $1::int +}.PG_GROUP_OFFSET.q{,
            'Default', $2,
            $3, $4
        );
    } );

    for (my $group=1; $group<=$GROUPS; $group++) {
        # pick random User to create the Group
        my $user_id = rand_pick @users;

        my $account = $user_to_pri_acct{$user_id};

        my $group_id = sql_nextval('groups___group_id');

        # create the Group
        my $group_name = "group-$group-$base";
        $create_group_sth->execute(
            $group_id, $group_name, $account, $user_id);
        $writes++;

        # associate group with account
        create_gar($group_id, $account);
        # creator gets admin role
        create_ugr($user_id,$group_id,$admin_id);

        push @groups, $group_id;
        maybe_commit();
    }
    print " done!\n";
}

{
    print "Assigning ".$GROUP_USER_RATIO*$GROUPS." User->Group Roles";

    my $basis = 1.5*$GROUP_USER_RATIO; # +/- 50% variance
    my $slope = -$GROUP_USER_RATIO / $GROUPS;
    my @rand_groups = shuffle @groups;

    for (my $i=0; $i < $GROUPS; $i++) {
        my $num_users = $slope * $i + $basis;
        next unless $num_users > 0;
        my $group_id = $rand_groups[$i];
        my @rand_users = rand_subset @users, $num_users;
        for my $user_id (@rand_users) {
            create_ugr($user_id, $group_id, $member_id);
        }
        maybe_commit();
    }

    print " done!\n";
}

{
    print "Assigning ".$GROUP_WS_RATIO*$GROUPS." Group->WS Roles";

    my $basis = 1.5*$GROUP_WS_RATIO; # +/- 50% variance
    my $slope = -$GROUP_WS_RATIO / $GROUPS;
    my @rand_groups = shuffle @groups;

    for (my $i=0; $i < $GROUPS; $i++) {
        my $num_ws = $slope * $i + $basis;
        next unless $num_ws > 0;
        my $group_id = $rand_groups[$i];
        my @rand_ws = rand_subset @workspaces, $num_ws;
        for my $ws_id (@rand_ws) {
            insert_role($group_id+GROUP_OFFSET, $ws_id+WKSP_OFFSET, $member_id);
        }
        maybe_commit();
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
        my $ws = rand_pick @workspaces;
        my $editor = rand_pick @users;
        my $creator = rand_pick @users;
        my $page_id = "page_${base}_$p";
        $page_sth->execute(
            $ws, $page_id, "Page: $base $p!",
            $editor, $creator,
            $create_ts, rand($PAGES).' seconds', $create_ts,
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
        my $actor = rand_pick @users;
        my $page = rand_pick @pages;
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

    my @classes = (('page') x 8, 'person');
    for (my $i=0; $i<$OTHER_EVENTS; $i++) {
        my $actor = rand_pick @users;
        my $page = [undef,undef];
        my $person = undef;
        my @actions;

        my $class = rand_pick @classes;
        if ($class eq 'page') {
            $page = rand_pick @pages;
            @actions = qw(tag_add watch_add watch_delete rename edit_save comment duplicate tag_delete delete);
        }
        else {
            $person = rand_pick @users;
            @actions = qw(tag_add watch_add tag_delete watch_delete edit_save);
        }
        my $action = rand_pick @actions;

        $ev_sth->execute(
            $create_ts, rand($PAGES).' seconds', 
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

    print "\n\tGetting user sets for each created user";
    my %user_sig_sets = ();
    my @signalusers = ();
    my $uss_sth= $dbh->prepare_cached(q{
        SELECT DISTINCT(into_set_id)
          FROM user_set_path path
          JOIN user_set_plugin_tc plug ON (path.into_set_id = plug.user_set_id)
         WHERE plugin = 'signals'
           AND from_set_id = ?
        });

    for (my $user=1; $user<=$USERS; $user++) {
        $uss_sth->execute($user);
        my @ids = map { $_->[0] } @{ $uss_sth->fetchall_arrayref() };
        if (@ids) {
            $user_sig_sets{$user}=\@ids;
            push @signalusers, $user;
        }
    }
    print " done!\ngenerating ";
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

    my $set_signal_sth = $dbh->prepare_cached(q{
        INSERT INTO signal_user_set (signal_id, user_set_id)
        VALUES (currval('signal_id_seq'), ?)
    });

    for ( my $i = 0; $i < $SIGNALS; $i++ ) {
        my $is_page_edit = (rand() < 0.2);
        my $user         = rand_pick @signalusers;
        my $action       = ($is_page_edit) ? 'edit_save' : 'signal';
        my $interval     = rand($SIGNALS) . ' seconds';
        my $page         = [ undef, undef ];

        $sig_sth->execute($user, "signal $i $is_page_edit", $interval);
        $writes++;

        $page = rand_pick @pages if $is_page_edit;

        $ev_sth->execute(
            $create_ts, $interval,
            'signal', $action, $user, $user, @$page[0,1]
        );
        $writes++;

        if ($is_page_edit) {
            $topic_sth->execute($page->[0], $page->[1]);
            $writes++;
            # TODO: some workspaces' accounts may not be signalable
            $set_signal_sth->execute($ws_to_acct{$page->[0]} + ACCT_OFFSET);
            $writes++;
        }
        else {
            my @sets;
            my $uss = $user_sig_sets{$user};
            # pick some user sets to signal to
            if (rand() < $SIG_BROADCAST_RATIO) {
                @sets = @$uss;
            }
            else {
                # pick one
                $sets[0] = rand_pick @$uss;
            }

            $set_signal_sth->execute($_) for @sets;
            $writes += @sets;
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

$commits++;
$total_writes += $writes;
$dbh->commit;

print "ALL DONE ($total_writes writes, $commits commits)!\n";
