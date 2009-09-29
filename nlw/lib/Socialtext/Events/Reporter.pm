package Socialtext::Events::Reporter;
# @COPYRIGHT@
use Moose;
use Socialtext::Encode ();
use Socialtext::SQL qw/sql_execute/;
use Socialtext::JSON qw/decode_json/;
use Socialtext::User;
use Socialtext::Pluggable::Adapter;
use Socialtext::Timer;
use Class::Field qw/field/;
use Socialtext::WikiText::Parser::Messages;
use Socialtext::WikiText::Emitter::Messages::HTML;
use Socialtext::Formatter::LinkDictionary;
use namespace::clean -except => 'meta';

has 'viewer' => (
    is => 'ro', isa => 'Socialtext::User',
);

has 'link_dictionary' => (
    is => 'ro', isa => 'Socialtext::Formatter::LinkDictionary',
    lazy_build => 1,
);

sub _build_link_dictionary { Socialtext::Formatter::LinkDictionary->new }

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    return bless {
        @_,
        _conditions => [],
        _condition_args => [],
        _outer_conditions => [],
        _outer_condition_args => [],
    }, $class;
}

sub add_condition {
    my $self = shift;
    my $cond = shift;
    push @{$self->{_conditions}}, $cond;
    push @{$self->{_condition_args}}, @_;
}

sub prepend_condition {
    my $self = shift;
    my $cond = shift;
    unshift @{$self->{_conditions}}, $cond;
    unshift @{$self->{_condition_args}}, @_;
}

sub add_outer_condition {
    my $self = shift;
    my $cond = shift;
    push @{$self->{_outer_conditions}}, $cond;
    push @{$self->{_outer_condition_args}}, @_;
}

sub prepend_outer_condition {
    my $self = shift;
    my $cond = shift;
    unshift @{$self->{_outer_conditions}}, $cond;
    unshift @{$self->{_outer_condition_args}}, @_;
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
        $self->_extract_tag($row);

        delete $row->{person}
            if (!defined($row->{person}) and $row->{event_class} ne 'person');

        $row->{at} = delete $row->{at_utc};

        push @$result, $row;
    }

    return $result;
}

my $FIELDS = <<'EOSQL';
    at AT TIME ZONE 'UTC' || 'Z' AS at_utc,
    at AS at,
    event_class AS event_class,
    action AS action,
    actor_id AS actor_id,
    person_id AS person_id,
    signal_id AS signal_id,
    page.page_id as page_id,
        page.name AS page_name,
        page.page_type AS page_type,
    w.name AS page_workspace_name,
        w.title AS page_workspace_title,
    tag_name AS tag_name,
    context AS context
EOSQL

my $SIGNAL_VIS_SQL = <<'EOSQL';
    AND account_id IN (
        SELECT account_id
        FROM signal_account sa
        WHERE sa.signal_id = evt.signal_id
    )
    AND (
        evt.person_id IS NULL
        OR evt.person_id = ?
        OR evt.actor_id = ?
    )
EOSQL

sub visible_exists {
    my $self = shift;
    my $plugin = shift;
    my $event_field = shift;
    my $opts = shift;
    my $bind_ref = shift;

    my $account_id = $opts->{account_id};

    my $sql = qq{
       EXISTS (
            SELECT 1
            FROM account_user viewer
            JOIN account_plugin USING (account_id)
            JOIN account_user othr USING (account_id)
            WHERE plugin = '$plugin' AND viewer.user_id = ?
              AND othr.user_id = $event_field
    };
    push @$bind_ref, $self->viewer->user_id;

    if ($account_id) {
        $sql .= "\nAND account_id = ?\n";
        push @$bind_ref, $account_id;
    }

    if ($plugin eq 'signals') {
        $sql .= $SIGNAL_VIS_SQL;
        push @$bind_ref, ($self->viewer->user_id) x 2;
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

my $VISIBLE_WORKSPACES = <<'EOSQL';
    SELECT workspace_id FROM user_workspace_role WHERE user_id = ?
    UNION ALL
    SELECT workspace_id
    FROM "WorkspaceRolePermission" wrp
    JOIN "Role" r USING (role_id)
    JOIN "Permission" p USING (permission_id)
    WHERE
        -- workspace vis
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
            $self->add_condition("e.$eq_key <> ?", $arg);
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

    my $viewer_id = $self->viewer->user_id;

    $self->_process_before_after($opts);

    unless ($self->{_skip_standard_opts}) {
        {
            my $visible_ws = $VISIBLE_WORKSPACES;
            my @bind = ($viewer_id);
            if ($opts->{account_id}) {
                $visible_ws = _limit_ws_to_account($visible_ws);
                push @bind, $opts->{account_id};
            }
            my $can_use_this_ws = qq{
                page_workspace_id IS NULL OR
                page_workspace_id IN ( $visible_ws )
            };
            $self->prepend_condition($can_use_this_ws => @bind);
        }

        unless ($self->{_skip_visibility}) {
            $self->add_outer_condition(
                $self->visibility_sql($opts)
            );
        }

        if ($opts->{followed}) {
            if ($opts->{with_my_signals}) {
                $self->add_condition(
                    $FOLLOWED_PEOPLE_ONLY_WITH_MY_SIGNALS => ($viewer_id) x 3
                );
            }
            else {
                $self->add_condition(
                    $FOLLOWED_PEOPLE_ONLY => ($viewer_id) x 2
                );
            }
        }

        if ($opts->{signals}) {
            $self->add_condition('signal_id IS NOT NULL');
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

    my $where = join("\n  AND ",
                     map {"($_)"} ('1=1',@{$self->{_conditions}},'NOT hidden'));
    my $outer_where = join("\n  AND ",
                           map {"($_)"} ('1=1',@{$self->{_outer_conditions}},'NOT hidden'));

    my $sql = <<EOSQL;
SELECT $FIELDS FROM (
    SELECT evt.* FROM (
        SELECT e.*
        FROM event e
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

-- the JOINs above mess up the order. Fortunately, the re-sort isn't too hideous after LIMIT-ing
ORDER BY outer_e.at DESC
EOSQL

    return $sql, [@{$self->{_condition_args}}, @{$self->{_outer_condition_args}}, @limit_args];
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

sub get_events_page_contribs {
    my $self = shift;
    my $opts = ref($_[0]) eq 'HASH' ? $_[0] : {@_};

    $self->add_condition(
        q{event_class = 'page' AND is_page_contribution(action)}
    );
    local $self->{_skip_visibility} = 1;
    my $filtered_opts = _filter_opts($opts, 
        qw(limit count offset before after action followed account_id)
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

sub _conversations_where {
    my $visible_ws = shift || $VISIBLE_WORKSPACES;
    return qq{
        event_class = 'page'
        AND is_page_contribution(action)
        AND e.actor_id <> ?
        AND page_workspace_id IN ( $visible_ws )
        AND (
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
            -- they contributed to it after i did
            EXISTS (
                SELECT 1
                FROM event my_contribs
                WHERE my_contribs.event_class = 'page'
                  AND is_page_contribution(my_contribs.action)
                  AND my_contribs.actor_id = ?
                  AND my_contribs.page_workspace_id
                        = e.page_workspace_id
                  AND my_contribs.page_id = e.page_id
                  AND my_contribs.at < e.at
            )
        )
    };
}

sub _build_convos_sql {
    my $self = shift;
    my $opts = shift;

    my $user_id = $opts->{user_id};

    # filter the options to a subset of what's usually allowed
    my $filtered_opts = _filter_opts($opts, qw(
       action actor_id page_workspace_id page_id tag_name account_id
       before after limit count offset
    ));

    local $self->{_skip_standard_opts} = 1;

    my $limit_public_to_contributed = <<EOSQL;
        workspace_id IN
        (
            SELECT page_workspace_id AS workspace_id
            FROM event has_contrib
            WHERE has_contrib.event_class = 'page'
              AND is_page_contribution(has_contrib.action)
              AND has_contrib.actor_id = ?
        ) AND
EOSQL
    (my $visible_ws = $VISIBLE_WORKSPACES) =~
        s/-- workspace vis/$limit_public_to_contributed/;
    my @bind = ($user_id); # actor_id <> ?
    push @bind, ($user_id) x 2; # ws visibility so far

    if ($filtered_opts->{account_id}) {
        $visible_ws = _limit_ws_to_account($visible_ws);
        push @bind, $filtered_opts->{account_id};
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

    if ($opts->{action} && $opts->{action} eq 'view') {
        return []; # view events aren't contributions
    }

    # by using non-view indexes, we can get a simple perf boost until we
    # devise something better
    $opts->{"action!"} = 'view';

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
    
    local $self->{_skip_standard_opts} = 1;
    local $self->{_skip_visibility} = 1;
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
__PACKAGE__->meta->make_immutable;

1;
