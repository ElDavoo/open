package Socialtext::Events::Reporter;
# @COPYRIGHT@
use Moose;
use Clone qw/clone/;
use Socialtext::Encode ();
use Socialtext::SQL qw/sql_execute sql_format_timestamptz/;
use Socialtext::JSON qw/decode_json/;
use Socialtext::User;
use Socialtext::Pluggable::Adapter;
use Socialtext::Timer;
use Socialtext::WikiText::Parser::Messages;
use Socialtext::WikiText::Emitter::Messages::HTML;
use Socialtext::Formatter::LinkDictionary;
use Socialtext::UserSet qw/:const/;
use namespace::clean -except => 'meta';

has 'viewer' => (
    is => 'ro', isa => 'Socialtext::User',
    handles => {
        viewer_id => 'user_id',
    }
);

has 'link_dictionary' => (
    is => 'ro', isa => 'Socialtext::Formatter::LinkDictionary',
    lazy_build => 1,
);

has 'table' => (
    is => 'rw', isa => 'Str', default => 'event',
    init_arg => undef,
);

{
    my @field_list = (
        [at_utc => "at AT TIME ZONE 'UTC' || 'Z'"],
        (map { [$_=>$_] } qw(
            at event_class action actor_id
            tag_name context
            person_id signal_id group_id
        )),
        [page_id => 'page.page_id'],
        [page_name => 'page.name'],
        [page_type => 'page.page_type'],
        [page_workspace_name => 'w.name'],
        [page_workspace_title => 'w.title'],
    );
    has 'field_list' => (
        is => 'rw', isa => 'ArrayRef',
        default => sub { clone \@field_list }, # copy it
        lazy => 1, auto_deref => 1,
        init_arg => undef,
    );
}

has $_ => (is => 'rw', isa => 'ArrayRef', default => sub {[]})
    for (qw(_condition_args _outer_condition_args));
has $_ => (is => 'rw', isa => 'ArrayRef', default => sub {['1=1']})
    for (qw(_conditions _outer_conditions));
has $_ => (is => 'rw', isa => 'Bool', default => undef, init_arg => undef)
    for (qw(_skip_visibility _skip_standard_opts _include_public_ws));

sub _build_link_dictionary { Socialtext::Formatter::LinkDictionary->new }

sub add_condition {
    my $self = shift;
    my $cond = shift;
    push @{$self->_conditions}, $cond;
    push @{$self->_condition_args}, @_;
}

sub prepend_condition {
    my $self = shift;
    my $cond = shift;
    unshift @{$self->_conditions}, $cond;
    unshift @{$self->_condition_args}, @_;
}

sub add_outer_condition {
    my $self = shift;
    my $cond = shift;
    push @{$self->_outer_conditions}, $cond;
    push @{$self->_outer_condition_args}, @_;
}

sub prepend_outer_condition {
    my $self = shift;
    my $cond = shift;
    unshift @{$self->_outer_conditions}, $cond;
    unshift @{$self->_outer_condition_args}, @_;
}

our @QueryOrder = qw(
    event_class
    action
    actor_id
    person_id
    page_workspace_id
    page_id
    tag_name
);

sub _best_full_name {
    my $p = shift;

    my $full_name;
    if ($p->{first_name} || $p->{last_name}) {
        $full_name = "$p->{first_name} $p->{last_name}";
    }
    elsif ($p->{email}) {
        ($full_name = $p->{email}) =~ s/@.*$//;
    }
    elsif ($p->{name}) {
        ($full_name = $p->{name}) =~ s/@.*$//;
    }
    return $full_name;
}

sub _extract_person {
    my ($self, $row, $prefix) = @_;
    my $id = delete $row->{"${prefix}_id"};
    return unless $id;

    # this real-name calculation may benefit from caching at some point
    my $real_name;
    my $user = Socialtext::User->new(user_id => $id);
    my $avatar_is_visible = $user->avatar_is_visible || 0;
    if ($user) {
        $real_name = $user->guess_real_name();
    }

    my $profile_is_visible = $user->profile_is_visible_to($self->viewer) || 0;
    my $hidden = 1;
    my $adapter = Socialtext::Pluggable::Adapter->new;
    if ($adapter->plugin_exists('people')) {
        require Socialtext::People::Profile;
        my $profile = Socialtext::People::Profile->GetProfile($user);
        $hidden = $profile->is_hidden if $profile;
    }

    $row->{$prefix} = {
        id => $id,
        best_full_name => $real_name,
        uri => $self->link_dictionary->format_link(
            link => 'people_profile',
            user_id => $id,
        ),
        hidden => $hidden,
        avatar_is_visible => $avatar_is_visible,
        profile_is_visible => $profile_is_visible,
    };
}

sub _extract_page {
    my $self = shift;
    my $row = shift;

    my $link_dictionary = $self->link_dictionary;

    my $page = {
        id => delete $row->{page_id} || undef,
        name => delete $row->{page_name} || undef,
        type => delete $row->{page_type} || undef,
        workspace_name => delete $row->{page_workspace_name} || undef,
        workspace_title => delete $row->{page_workspace_title} || undef,
    };

    if ($page->{workspace_name}) {
        $page->{workspace_uri} = $link_dictionary->format_link(
            link => 'interwiki',
            workspace => $page->{workspace_name},
        );

        if ($page->{id}) {
            $page->{uri} = $link_dictionary->format_link(
                link => 'interwiki',
                workspace => $page->{workspace_name},
                page_uri => $page->{id},
            );
        }
    }

    $row->{page} = $page if ($row->{event_class} eq 'page');
}

sub _extract_tag {
    my $self = shift;
    my $row = shift;
    my $link_dictionary = $self->link_dictionary;

    if ($row->{tag_name}) {
        if (my $page = $row->{page}) {
            $row->{tag_uri} = $link_dictionary->format_link(
                link => 'category',
                workspace => $page->{workspace_name},
                category => $row->{tag_name},
            );
        }
        elsif ($row->{person}) {
            $row->{tag_uri} = $link_dictionary->format_link(
                link => 'people_tag',
                tag_name => $row->{tag_name},
            );
        }
    }
}

sub _expand_context {
    my $self = shift;
    my $row = shift;
    my $c = $row->{context};
    if ($c) {
        local $@;
        $c = Encode::encode_utf8(Socialtext::Encode::ensure_is_utf8($c));
        $c = eval { decode_json($c) };
        warn $@ if $@;
    }
    $c = defined($c) ? $c : {};
    $row->{context} = $c;
}

sub _extract_signal {
    my $self = shift;
    my $row = shift;
    return unless $row->{event_class} eq 'signal';
    my $parser = Socialtext::WikiText::Parser::Messages->new(
       receiver => Socialtext::WikiText::Emitter::Messages::HTML->new(
           callbacks => {
               link_dictionary => $self->link_dictionary,
               viewer => $self->viewer,
           },
       )
    );
    $row->{context}{body} = $parser->parse($row->{context}{body});
}

sub _extract_group {
    my $self = shift;
    my $row = shift;
    return unless $row->{group_id};
    my $group_id = $row->{group_id};
    my $group = Socialtext::Group->GetGroup(group_id => $group_id);
    $row->{group} = {
        name => $group->display_name,
        id => $group_id,
        uri => $self->link_dictionary->format_link(
            link => 'group',
            group_id => $group_id,
        ),
    };

    if (my $ws_id = $row->{context}{workspace_id}) {
        my $wksp = Socialtext::Workspace->new(workspace_id => $ws_id);
        return unless $wksp;
        $row->{page} = {
            workspace_uri => $self->link_dictionary->format_link(
                link => 'interwiki',
                workspace => $wksp->name,
            ),
            workspace_title => $wksp->title,
        };
    }
}

sub decorate_event_set {
    my $self = shift;
    my $sth = shift;

    my $result = [];

    while (my $row = $sth->fetchrow_hashref) {
        $self->_extract_person($row, 'actor');
        $self->_extract_person($row, 'person');
        $self->_extract_page($row);
        $self->_expand_context($row);
        $self->_extract_signal($row);
        $self->_extract_group($row);
        $self->_extract_tag($row);

        delete $row->{person}
            if (!defined($row->{person}) and $row->{event_class} ne 'person');

        $row->{at} = delete $row->{at_utc};

        push @$result, $row;
    }

    return $result;
}

sub signal_vis_sql {
    my $self = shift;
    my $evtable = shift;
    my $path_table = shift;
    my $bind_ref = shift;
    my $opts = shift;

    my $direct = $opts->{direct} || 'both';
    my $dm_sql = 'FALSE';
    if ($direct ne 'none') {
        my $dir_sql = join(" OR ",
            $direct =~ /^(?:received|both)$/ ? "$evtable.person_id = ?" : (),
            $direct =~ /^(?:sent|both)$/ ? "$evtable.actor_id = ?" : (),
        );
        die "Invalid direct parameter: $direct" unless $dir_sql;

        $dm_sql = qq{
            -- the signal is direct
            ($dir_sql)

            -- and the filtered network contains both users
            AND EXISTS (
                SELECT 1
                FROM user_sets_for_user usfu
                WHERE usfu.user_id = $evtable.person_id
                  AND $path_table.user_set_id = usfu.user_set_id
            )
        };
        push @$bind_ref, ($self->viewer->user_id) x 2;
    }

    return qq{ 
        AND ((
                $evtable.person_id IS NULL
                AND user_set_id IN (
                    SELECT user_set_id
                    FROM signal_user_set sua
                    WHERE sua.signal_id = $evtable.signal_id
                )
            )
            OR ( $dm_sql )
        )
    };
};

sub visible_exists {
    my $self = shift;
    my $plugin = shift;
    my $event_field = shift;
    my $opts = shift;
    my $bind_ref = shift;
    my $evt_table = shift || 'evt';

    my $sql = qq{
       EXISTS (
            SELECT 1
              -- "viewer and event-record user share some user set..."
              FROM user_sets_for_user v_path
              JOIN user_sets_for_user o_path USING (user_set_id)
             WHERE v_path.user_id = ? -- viewer
               AND o_path.user_id = $event_field
               -- "...and that common user set has access to some plugin"
               AND EXISTS (
                   SELECT 1
                     FROM user_set_plugin_tc plug
                    WHERE plugin = '$plugin'
                      AND plug.user_set_id = o_path.user_set_id
               )
    };
    push @$bind_ref, $self->viewer_id;

    my $account_id = $opts->{account_id};
    my $group_id = $opts->{group_id};
    if ($account_id) {
        $sql .= "\nAND user_set_id = ?\n";
        push @$bind_ref, $account_id + ACCT_OFFSET;
    }
    elsif ($group_id) {
        $sql .= "\nAND user_set_id = ?\n";
        push @$bind_ref, $group_id + GROUP_OFFSET;
    }

    if ($plugin eq 'signals') {
        $sql .= $self->signal_vis_sql($evt_table, 'v_path', $bind_ref, $opts);
    }

    $sql .= "\n)";
    return $sql;
}

sub no_signals_are_visible {
    my $self = shift;
    my $opts = shift;
    {
        local $@;
        return 1 unless eval "require Socialtext::Signal; 1;";
    }
    return unless Socialtext::Signal->Can_shortcut_events({
        %$opts, viewer => $self->viewer
    });
    push @Socialtext::Rest::EventsBase::ADD_HEADERS,
        ('X-Events-Optimize' => 'signal-shortcut');
    return 1;
}

sub visibility_sql {
    my $self = shift;
    my $opts = shift;
    my @parts;
    my @bind;

    if (_options_include_class($opts, 'person') &&
        $self->viewer->can_use_plugin('people')
    ) {
        push @parts,
            "(evt.event_class <> 'person' OR (".
                $self->visible_exists('people','evt.actor_id',$opts,\@bind).
                "AND".
                $self->visible_exists('people','evt.person_id',$opts,\@bind).
            '))';
    }
    else {
        push @parts, "(evt.event_class <> 'person')";
    }

    if (_options_include_class($opts, 'signal')
        and $self->viewer->can_use_plugin('signals') 
        and not $self->no_signals_are_visible($opts)
    ) {
        push @parts,
            "( evt.event_class <> 'signal' OR".
                $self->visible_exists('signals','evt.actor_id',$opts,\@bind).
            ')';
    }
    else {
        push @parts, "(evt.event_class <> 'signal')";
    }

    if (_options_include_class($opts, 'widget')
        and $self->viewer->can_use_plugin('widgets') 
    ) {
        push @parts,
            "( evt.event_class <> 'widget' OR".
                $self->visible_exists('widgets','evt.actor_id',$opts,\@bind).
            ')';
    }
    else {
        push @parts, "(evt.event_class <> 'widget')";
    }

    my $sql;
    $sql = "\n(\n".join(" AND ",@parts)."\n)\n";

    return $sql,@bind;
}

my $VISIBLE_WORKSPACES = q{
    SELECT into_set_id - }.PG_WKSP_OFFSET.q{ AS workspace_id FROM user_set_include_tc WHERE from_set_id = ?
};

my $PUBLIC_WORKSPACES = <<'EOSQL';
    SELECT workspace_id
    FROM "WorkspaceRolePermission" wrp
    JOIN "Role" r USING (role_id)
    JOIN "Permission" p USING (permission_id)
    WHERE
        r.name = 'guest' AND p.name = 'read'
EOSQL

sub _limit_ws_to_account {
    my $visible_ws = shift || $VISIBLE_WORKSPACES;
    return qq{
        SELECT workspace_id
        FROM ( $visible_ws ) visws
        WHERE workspace_id IN (
            SELECT workspace_id FROM "Workspace" WHERE account_id = ?
        )
    };
}

sub _limit_ws_to_group {
    my $visible_ws = shift || $VISIBLE_WORKSPACES;
    return qq{
        SELECT workspace_id
        FROM ( $visible_ws ) visgrp
        WHERE workspace_id + }.PG_WKSP_OFFSET .q{ IN (
            SELECT into_set_id
              FROM user_set_path
             WHERE from_set_id = ?
               AND into_set_id }.PG_WKSP_FILTER.q{
        )
    };
}

my $FOLLOWED_PEOPLE_ONLY = <<'EOSQL';
(
   (actor_id IN (
        SELECT person_id2
        FROM person_watched_people__person
        WHERE person_id1=?))
   OR
   (person_id IN (
        SELECT person_id2
        FROM person_watched_people__person
        WHERE person_id1=?))
)
EOSQL

my $FOLLOWED_PEOPLE_ONLY_WITH_MY_SIGNALS = <<"EOSQL";
(
   $FOLLOWED_PEOPLE_ONLY
   OR (event_class = 'signal' AND actor_id = ?)
)
EOSQL

my $CONTRIBUTIONS = <<'EOSQL';
    (event_class = 'person' AND is_profile_contribution(action))
    OR
    (event_class = 'page' AND is_page_contribution(action))
    OR
    (event_class = 'signal')
EOSQL

sub _process_before_after {
    my $self = shift;
    my $opts = shift;
    if (my $b = $opts->{before}) {
        $self->add_condition('at < ?::timestamptz', $b);
    }
    if (my $a = $opts->{after}) {
        $self->add_condition('at > ?::timestamptz', $a);
    }
}

sub _process_field_conditions {
    my $self = shift;
    my $opts = shift;

    foreach my $eq_key (@QueryOrder) {
        next unless exists $opts->{$eq_key};

        my $arg = $opts->{$eq_key};
        if ((defined $arg) && (ref($arg) eq "ARRAY")) {
            my $placeholders = "(".join(",", map( "?", @$arg)).")";
            $self->add_condition("e.$eq_key IN $placeholders", @$arg);
        }
        elsif (defined $arg) {
            $self->add_condition("e.$eq_key = ?", $arg);
        }
        else {
            $self->add_condition("e.$eq_key IS NULL");
        }
    }

    foreach my $eq_key (@QueryOrder) {
        my $ne_key = "$eq_key!";
        next unless exists $opts->{$ne_key};

        my $arg = $opts->{$ne_key};
        if ((defined $arg) && (ref($arg) eq "ARRAY")) {
            my $placeholders = "(".join(",", map( "?", @$arg)).")";
            $self->add_condition("e.$eq_key NOT IN $placeholders", @$arg);
        }
        elsif (defined $arg) {
            # view events are no longer in the DB
            $self->add_condition("e.$eq_key <> ?", $arg)
                unless $arg eq 'view';
        }
        else {
            $self->add_condition("e.$eq_key IS NOT NULL");
        }
    }
}

sub _limit_and_offset {
    my $self = shift;
    my $opts = shift;

    my @args;

    my $limit = '';
    if (my $l = $opts->{limit} || $opts->{count}) {
        $limit = 'LIMIT ?';
        push @args, $l;
    }
    my $offset = '';
    if (my $o = $opts->{offset}) {
        $offset = 'OFFSET ?';
        push @args, $o;
    }

    my $statement = join(' ',$limit,$offset);
    return ($statement, @args);
}

sub _options_include_class {
    my $opts = shift;
    my $class = shift;

    return 1 unless $opts->{event_class};

    if (ref($opts->{event_class})) {
        return 1 if grep { $_ eq $class } @{$opts->{event_class}};
    }
    else {
        return 1 if $opts->{event_class} eq $class;
    }
    return 0;
}


sub _build_standard_sql {
    my $self = shift;
    my $opts = shift;

    my $table = $self->table;

    $self->_process_before_after($opts);

    unless ($self->_skip_standard_opts) {
        {
            my $visible_ws = $VISIBLE_WORKSPACES;
            if ($self->_include_public_ws) {
                $visible_ws .= ' UNION ALL '.$PUBLIC_WORKSPACES;
            }
            my @bind = ($self->viewer_id);
            if ($opts->{account_id}) {
                $visible_ws = _limit_ws_to_account($visible_ws);
                push @bind, $opts->{account_id};
            }
            elsif ($opts->{group_id}) {
                $visible_ws = _limit_ws_to_group($visible_ws);
                push @bind, $opts->{group_id} + GROUP_OFFSET;
            }
            my $can_use_this_ws = qq{
                -- start "can_use_this_ws"
                page_workspace_id IS NULL OR page_workspace_id IN (
                    $visible_ws
                )
                -- end "can_use_this_ws"
            };
            $self->prepend_condition($can_use_this_ws => @bind);
        }

        unless ($self->_skip_visibility) {
            $self->add_outer_condition(
                $self->visibility_sql($opts)
            );
        }

        if ($opts->{followed}) {
            if ($opts->{with_my_signals}) {
                $self->add_condition(
                    $FOLLOWED_PEOPLE_ONLY_WITH_MY_SIGNALS => ($self->viewer_id) x 3
                );
            }
            else {
                $self->add_condition(
                    $FOLLOWED_PEOPLE_ONLY => ($self->viewer_id) x 2
                );
            }
        }

        if ($opts->{signals}) {
            $self->add_condition('signal_id IS NOT NULL');
        }

        if ($opts->{group_id} and $table ne 'event_page_contrib') {
            $self->add_condition(
                "event_class <> 'group' OR group_id = ?", $opts->{group_id}
            );
        }

        if ($opts->{activity} && $opts->{activity} eq 'all-combined') {
            $self->add_condition('NOT is_ignorable_action(event_class,action)');
        }

        # filter for contributions-type events
        $self->add_condition($CONTRIBUTIONS)
            if $opts->{contributions};
    }

    $self->_process_field_conditions($opts);

    my ($limit_stmt, @limit_args) = $self->_limit_and_offset($opts);

    if ($table ne 'event_page_contrib') {
        # event_page_contrib doesn't have a hidden column
        $self->add_condition('NOT hidden');
        $self->add_outer_condition('NOT hidden');
    }

    # strange code indentation is for SQL alignment
    my $where = join("
          AND ",map {"($_)"} @{$self->_conditions});
    my $outer_where = join("
      AND ", map {"($_)"} @{$self->_outer_conditions});

    my $fields = join(",\n\t", map { "$_->[1] AS $_->[0]" } $self->field_list);

    my $sql = <<EOSQL;
SELECT $fields
  FROM (
    SELECT evt.* FROM (
        SELECT e.*
        FROM $table e
        WHERE $where
        ORDER BY at DESC
    ) evt
    WHERE
    $outer_where
    $limit_stmt
) outer_e
LEFT JOIN page ON (outer_e.page_workspace_id = page.workspace_id AND
                   outer_e.page_id = page.page_id)
LEFT JOIN "Workspace" w ON (outer_e.page_workspace_id = w.workspace_id)
-- the JOINs above mess up the "ORDER BY at DESC".
-- Fortunately, the re-sort isn't too hideous after LIMIT-ing
ORDER BY outer_e.at DESC
EOSQL

    return $sql, [@{$self->_condition_args}, @{$self->_outer_condition_args}, @limit_args];
}

sub _get_events {
    my $self   = shift;
    my $opts = ref($_[0]) eq 'HASH' ? $_[0] : {@_};

    # Try to shortcut a pure signals query.
    # "just signal events or just signal actions or the magic signals flag":
    if (( !$opts->{event_class} &&
          $opts->{action} &&
          !ref($opts->{action}) &&
          $opts->{action} eq 'signal' ) or 
        ( $opts->{event_class} &&
          !ref($opts->{event_class}) &&
          $opts->{event_class} eq 'signal' ) or
        ( $opts->{signals} )
    ) {
        if (!$self->viewer->can_use_plugin('signals')) {
            push @Socialtext::Rest::EventsBase::ADD_HEADERS,
                ('X-Events-Optimize' => 'no-plugin-access');
            return [];
        }
        return [] if $self->no_signals_are_visible($opts);
    }

    my ($sql, $args) = $self->_build_standard_sql($opts);

    Socialtext::Timer->Continue('get_events');
    #$Socialtext::SQL::PROFILE_SQL = 1;
    my $sth = sql_execute($sql, @$args);
    #$Socialtext::SQL::PROFILE_SQL = 0;
    my $result = $self->decorate_event_set($sth);
    Socialtext::Timer->Pause('get_events');

    return @$result if wantarray;
    return $result;
}

my %can_negate = map {$_=>1} qw(
    action tag_name actor_id person_id
);

sub _filter_opts {
    my $opts = shift;
    my @allowed = @_;

    my %filtered;
    # check for definedness; NULL values can't use an index so disallow them
    for my $k (@allowed) {
        $filtered{$k} = $opts->{$k} if defined $opts->{$k};
        next unless $can_negate{$k};
        $filtered{"$k!"} = $opts->{"$k!"} if defined $opts->{"$k!"};
    }

    return \%filtered;
}

sub get_events {
    my $self   = shift;
    my $opts = ref($_[0]) eq 'HASH' ? $_[0] : {@_};

    if ($opts->{event_class} && !(ref $opts->{event_class}) &&
        $opts->{event_class} eq 'page' && $opts->{contributions})
    {
        return $self->get_events_page_contribs($opts);
    }

    return $self->_get_events($opts);
}

# Switches the query generator to use the `event_page_contrib` table rather
# than the usual `event` table.  The usual non-page event visibility checks
# are also turned off; the query can only ever return page events with this
# table.
sub use_event_page_contrib {
    my $self = shift;

    $self->table('event_page_contrib');
    for my $field ($self->field_list) {
        my ($k,$defn) = @$field;
        if ($k eq 'event_class') {
            $defn = "'page'";
        }
        elsif ($k =~ /^(?:person_id|signal_id|group_id)$/) {
            $defn = "NULL";
        }
        $field->[1] = $defn;
    }
    $self->_skip_visibility(1);
}

sub get_events_page_contribs {
    my $self = shift;
    my $opts = ref($_[0]) eq 'HASH' ? $_[0] : {@_};

    $self->use_event_page_contrib();
    my $filtered_opts = _filter_opts($opts, 
        qw(limit count offset before after action followed account_id group_id)
    );
    my ($sql, $args) = $self->_build_standard_sql($filtered_opts);

    Socialtext::Timer->Continue('get_page_contribs');
    #$Socialtext::SQL::PROFILE_SQL = 1;
    my $sth = sql_execute($sql, @$args);
    #$Socialtext::SQL::PROFILE_SQL = 0;
    my $result = $self->decorate_event_set($sth);
    Socialtext::Timer->Pause('get_page_contribs');

    return @$result if wantarray;
    return $result;
}

sub get_events_activities {
    my $self = shift;
    my $maybe_user = shift;
    my $opts = ref($_[0]) eq 'HASH' ? $_[0] : {@_};

    Socialtext::Timer->Continue('get_activity');

    # First we need to get the user id in case this was email or username used
    my $user = Socialtext::User->Resolve($maybe_user);
    my $user_id = $user->user_id;

    $self->_include_public_ws(1);

    my $user_ids;
    my @conditions;
    if (!$opts->{event_class}) {
        $opts->{event_class} = [qw(page person signal)];
    }

    my %classes;
    if (ref $opts->{event_class}) {
        %classes = map {$_ => 1} @{$opts->{event_class}};
    }
    else {
        $classes{$opts->{event_class}} = 1;
    }

    if ($classes{page}) {
        push @conditions, q{
            event_class = 'page'
            AND is_page_contribution(action)
            AND actor_id = ?
        };
        $user_ids++;
    }

    if ($classes{person}) {
        push @conditions, q{
            -- target ix_event_person_contribs_actor
            (event_class = 'person' AND is_profile_contribution(action)
                AND actor_id = ?)
            OR
            -- target ix_event_person_contribs_person
            (event_class = 'person' AND is_profile_contribution(action)
                AND person_id = ?)
        };
        $user_ids += 2;
    }

    if ($classes{signal}) {
        push @conditions, q{
            event_class = 'signal' AND (
                actor_id = ?
                OR EXISTS (
                    SELECT 1
                      FROM topic_signal_user tsu
                     WHERE tsu.signal_id = e.signal_id
                       AND tsu.user_id = ?
                )
                OR person_id = ?
            )
        };
        $user_ids += 3;
    }

    my $cond_sql = join(' OR ', map {"($_)"} @conditions);
    $self->add_condition($cond_sql, ($user_id) x $user_ids);
    my $evs = $self->_get_events(@_);
    Socialtext::Timer->Pause('get_activity');

    return @$evs if wantarray;
    return $evs;
}

sub get_events_group_activities {
    my $self     = shift;
    my $group    = shift;
    my $group_id = $group->group_id;
    my $group_set_id = $group->user_set_id;
    my $opts     = ref($_[0]) eq 'HASH' ? $_[0] : {@_};

    Socialtext::Timer->Continue('get_gactivity');

    unless ($opts->{after}) {
        my $created = $group->creation_datetime;
        my $cut_off = DateTime->now - DateTime::Duration->new(weeks => 4);
        if ($created > $cut_off) {
            my $lower_bound = sql_format_timestamptz($created);
            $opts->{after} = $lower_bound;
        }
    }

    my @binds = ();
    my $groupsig_sql = $self->visible_exists('signals','e.actor_id', 
        {
            group_id => $group_id
        }, 
        \@binds, 'e');

    $self->add_condition(q{
        ( event_class = 'group' AND group_id = ? )
        OR (
            event_class = 'page'
            AND is_page_contribution(action)
            AND EXISTS ( -- the event's actor is in this group
                SELECT 1
                  FROM user_set_path
                 WHERE from_set_id = e.actor_id
                   AND into_set_id = ?
            )
            AND EXISTS ( -- the group is in the event's workspace
                SELECT 1
                  FROM user_set_path usp
                 WHERE e.page_workspace_id = into_set_id - }.PG_WKSP_OFFSET.q{
                   AND from_set_id = ?
                   AND NOT EXISTS (
                      SELECT 1
                        FROM user_set_path_component uspc
                       WHERE uspc.user_set_path_id = usp.user_set_path_id
                         AND uspc.user_set_id }.PG_ACCT_FILTER.q{
                   )
            )
        )
       OR (
        }.$groupsig_sql.q{
        )
    }, $group_id, $group_set_id, $group_set_id, @binds);

    $self->_skip_standard_opts(1);
    my $evs = $self->_get_events($opts);
    Socialtext::Timer->Pause('get_gactivity');

    return @$evs if wantarray;
    return $evs;
}

sub get_events_workspace_activities {
    my $self     = shift;
    my $workspace    = shift;
    my $opts     = ref($_[0]) eq 'HASH' ? $_[0] : {@_};

    Socialtext::Timer->Continue('get_gactivity');

    $self->add_condition(q{
        (
            event_class = 'page'
            AND is_page_contribution(action)
            AND e.page_workspace_id = ?
            AND EXISTS (
                SELECT 1
                  FROM user_set_path
                 WHERE from_set_id = e.actor_id
                   AND into_set_id = ?
                 LIMIT 1
            )
        )
    }, $workspace->workspace_id, $workspace->user_set_id);

    $self->_skip_standard_opts(1);
    my $evs = $self->_get_events(@_);
    Socialtext::Timer->Pause('get_gactivity');

    return @$evs if wantarray;
    return $evs;
}

sub _conversations_where {
    my $visible_ws = shift || $VISIBLE_WORKSPACES;
    return qq{
        e.actor_id <> ?
        AND page_workspace_id IN (
            $visible_ws
        ) -- end page_workspace_id IN
        AND ( -- start convos clause
            -- it's in my watchlist
            EXISTS (
                SELECT 1
                FROM "Watchlist" wl
                WHERE e.page_workspace_id = wl.workspace_id
                  AND wl.user_id = ?
                  AND e.page_id = wl.page_text_id::text
            )
            OR
            -- i created it
            EXISTS (
                SELECT 1
                FROM page p
                WHERE p.workspace_id = e.page_workspace_id
                  AND p.page_id = e.page_id
                  AND p.creator_id = ?
            )
            OR
            -- they contributed to it after i did. targets the
            -- ix_epc_actor_page_at index.
            EXISTS (
                SELECT 1
                FROM event_page_contrib my_contribs
                WHERE my_contribs.actor_id = ?
                  AND my_contribs.page_workspace_id = e.page_workspace_id
                  AND my_contribs.page_id = e.page_id
                  AND my_contribs.at < e.at
            )
        ) -- end convos clause
    };
}

sub _build_convos_sql {
    my $self = shift;
    my $opts = shift;

    my $user_id = $opts->{user_id};

    $self->use_event_page_contrib();
    $self->_skip_standard_opts(1);

    # filter the options to a subset of what's usually allowed
    my $filtered_opts = _filter_opts($opts, qw(
       action actor_id page_workspace_id page_id tag_name account_id group_id
       before after limit count offset
    ));

    my @bind = ($user_id); # the `actor_id <> ?` part of the big convos SQL

    my $visible_ws = qq{
    $VISIBLE_WORKSPACES
    UNION ALL
    $PUBLIC_WORKSPACES
        AND workspace_id IN (
            SELECT page_workspace_id AS workspace_id
            FROM event_page_contrib has_contrib
            WHERE has_contrib.actor_id = ?
        )
    };
    push @bind, ($user_id) x 2; # for $visible_ws

    if ($filtered_opts->{account_id}) {
        $visible_ws = _limit_ws_to_account($visible_ws);
        push @bind, $filtered_opts->{account_id};
    }
    elsif ($filtered_opts->{group_id}) {
        $visible_ws = _limit_ws_to_group($visible_ws);
        push @bind, $filtered_opts->{group_id} + GROUP_OFFSET;
    }

    my $conv_where = _conversations_where($visible_ws);
    push @bind, ($user_id) x 3;
    $self->prepend_condition($conv_where, @bind);

    return $self->_build_standard_sql($filtered_opts);
}

sub get_events_conversations {
    my $self = shift;
    my $maybe_user = shift;
    my $opts = (@_==1) ? $_[0] : {@_};

    # First we need to get the user id in case this was email or username used
    my $user = Socialtext::User->Resolve($maybe_user);
    my $user_id = $user->user_id;
    $opts->{user_id} = $user_id;

    my ($sql, $args) = $self->_build_convos_sql($opts);

    return [] unless $sql;

    Socialtext::Timer->Continue('get_convos');

    #$Socialtext::SQL::PROFILE_SQL = 1;
    my $sth = sql_execute($sql, @$args);
    #$Socialtext::SQL::PROFILE_SQL = 0;
    my $result = $self->decorate_event_set($sth);

    Socialtext::Timer->Pause('get_convos');

    return @$result if wantarray;
    return $result;
}

sub get_events_followed {
    my $self = shift;
    my $opts = (@_ == 1) ? $_[0] : {@_};

    $opts->{followed} = 1;
    $opts->{contributions} = 1;
    die "no limit?!" unless $opts->{count};

    my ($followed_sql, $followed_args) = $self->_build_standard_sql($opts);

    Socialtext::Timer->Continue('get_followed_events');
    #$Socialtext::SQL::PROFILE_SQL = 1;
    my $sth = sql_execute($followed_sql, @$followed_args);
    #$Socialtext::SQL::PROFILE_SQL = 0;
    my $result = $self->decorate_event_set($sth);
    Socialtext::Timer->Pause('get_followed_events');
    return $result;
}

sub get_page_contention_events {
    my $self = shift;
    my $opts = (@_==1) ? shift : {@_};
    
    $self->_skip_standard_opts(1);
    $self->_skip_visibility(1);
    $opts->{event_class} = 'page';
    $opts->{action} = [qw(edit_start edit_cancel)];
    my ($sql, $args) = $self->_build_standard_sql($opts);

    Socialtext::Timer->Continue('get_page_contention_events');
    #$Socialtext::SQL::PROFILE_SQL = 1;
    my $sth = sql_execute($sql, @$args);
    #$Socialtext::SQL::PROFILE_SQL = 0;
    Socialtext::Timer->Pause('get_page_contention_events');
    my $result = $self->decorate_event_set($sth);
    return $result;
}
__PACKAGE__->meta->make_immutable(inline_constructor => 1);

1;
