package Socialtext::Model::Pages;
# @COPYRIGHT@
use strict;
use warnings;
use Socialtext::Model::Page;
use Socialtext::SQL qw/sql_execute sql_singlevalue/;
use Socialtext::Timer qw/time_scope/;
use Carp qw/croak/;

our $MODEL_FIELDS = <<EOT;
    page.workspace_id, 
    "Workspace".name AS workspace_name, 
    "Workspace".title AS workspace_title, 
    page.page_id, 
    page.name, 
    page.last_editor_id AS last_editor_id, 
    -- _utc suffix is to prevent performance-impacing naming collisions:
    page.last_edit_time AT TIME ZONE 'UTC' AS last_edit_time_utc,
    page.creator_id,
    -- _utc suffix is to prevent performance-impacing naming collisions:
    page.create_time AT TIME ZONE 'UTC' AS create_time_utc,
    page.current_revision_id, 
    page.current_revision_num, 
    page.revision_count, 
    page.page_type, 
    page.deleted, 
    page.summary,
    page.edit_summary
EOT

sub By_seconds_limit {
    my $class         = shift;
    my $t             = time_scope 'By_seconds_limit';
    my %p             = @_;
    my $since         = $p{since};
    my $seconds       = $p{seconds};
    my $workspace_ids = $p{workspace_ids};
    my $workspace_id  = $p{workspace_id};
    my $offset        = $p{offset};
    my $limit         = $p{count} || $p{limit};
    my $tag           = $p{tag} || $p{category};
    my $hub           = $p{hub};
    my $type          = $p{type};
    my $order_by      = $p{order_by} || 'page.last_edit_time DESC';

    my $where;
    my @bind;
    if ( $since ) {
        $where = q{last_edit_time > ?::timestamptz};
        @bind  = ( $since );
    }
    elsif ( $seconds ) {
        $where = q{last_edit_time > 'now'::timestamptz - ?::interval};
        @bind  = ("$seconds seconds");
    }
    else {
        croak "seconds or count parameter is required";
    }

    return $class->_fetch_pages(
        hub => $hub,
        $workspace_ids ? ( workspace_ids => $workspace_ids ) : (),
        type         => $type,
        where        => $where,
        offset       => $offset,
        limit        => $limit,
        tag          => $tag,
        bind         => \@bind,
        order_by     => $order_by,
        workspace_id => $workspace_id,
        do_not_need_tags => $p{do_not_need_tags},
        deleted_ok   => $p{deleted_ok},
    );
}

sub All_active {
    my $class        = shift;
    my $t            = time_scope 'All_active';
    my %p            = @_;
    my $hub          = $p{hub};
    my $limit        = $p{count} || $p{limit};
    my $workspace_id = $p{workspace_id};
    my $no_tags      = $p{do_not_need_tags};
    my $order_by     = $p{order_by};
    my $offset       = $p{offset};
    my $type         = $p{type};
    my $orphaned     = $p{orphaned} || 0;

    $limit = 500 unless defined $limit;

    return $class->_fetch_pages(
        hub          => $hub,
        limit        => $limit,
        workspace_id => $workspace_id,
        do_not_need_tags => $no_tags,
        ($order_by ? (order_by => "page.$order_by") : ()),
        offset       => $offset,
        type         => $type,
        orphaned     => $orphaned,
    );
}

sub By_tag {
    my $class        = shift;
    my $t            = time_scope 'By_tag';
    my %p            = @_;
    my $hub          = $p{hub};
    my $workspace_id = $p{workspace_id};
    my $limit        = $p{count} || $p{limit};
    my $offset       = $p{offset};
    my $tag          = $p{tag};
    my $order_by     = $p{order_by} || 'page.last_edit_time DESC';
    my $no_tags      = $p{do_not_need_tags};
    my $type         = $p{type};

    return $class->_fetch_pages(
        hub              => $hub,
        workspace_id     => $workspace_id,
        limit            => $limit,
        offset           => $offset,
        tag              => $tag,
        order_by         => $order_by,
        do_not_need_tags => $no_tags,
        type             => $type,
    );
}

sub By_id {
    my $class            = shift;
    my $t                = time_scope 'By_id';
    my %p                = @_;
    my $hub              = $p{hub};
    my $workspace_id     = $p{workspace_id};
    my $page_id          = $p{page_id};
    my $do_not_need_tags = $p{do_not_need_tags};
    my $no_die           = $p{no_die};

    my $where;
    my $bind;
    if (ref($page_id) eq 'ARRAY') {
        return [] unless @$page_id;

        $where = 'page_id IN (' 
            . join(',', map { '?' } @$page_id) . ')';
        $bind = $page_id;
    }
    else {
        $where = 'page_id = ?';
        $bind = [$page_id];
    }

    my $pages = $class->_fetch_pages(
        hub              => $hub,
        workspace_id     => $workspace_id,
        where            => $where,
        bind             => $bind,
        do_not_need_tags => $p{do_not_need_tags},
        deleted_ok       => $p{deleted_ok},
    );
    unless (@$pages) {
        return if $no_die;
        my $pg_ids = join(',', (ref($page_id) ? @$page_id : ($page_id)));
        die "No page(s) found for ($workspace_id, $pg_ids)"
    }
    return @$pages == 1 ? $pages->[0] : $pages;
}

sub _fetch_pages {
    my $class = shift;
    my %p = (
        bind             => [],
        where            => '',
        deleted          => 0,
        tag              => undef,
        workspace_id     => undef,
        workspace_ids    => undef,
        order_by         => undef,
        limit            => undef,
        offset           => undef,
        do_not_need_tags => 0,
        deleted_ok       => undef,
        orphaned         => 0,
        @_,
    );

    my $tag       = '';
    my $more_join = '';
    if ( $p{tag} ) {
        $more_join = 'JOIN page_tag USING (page_id, workspace_id)';
        $p{where} .= ' AND ' if $p{where};
        $p{where} .= 'LOWER(page_tag.tag) = LOWER(?)';
        push @{ $p{bind} }, $p{tag};
    }

    # If ordering by a user, add the extra join and order by the display name
    if ( ($p{order_by}||'') =~ m/(creator_id|last_editor_id) (\S+)$/ ) {
        $p{order_by} = "LOWER(users.display_name) $2";
        $more_join .= " JOIN users ON (page.$1 = users.user_id)";
    }
    # If ordering by page name, make sure the order is case insensitive
    if ( ($p{order_by}||'') =~ m/page\.name(?: (\S+))?$/ ) {
        $p{order_by} = "LOWER(page.name) $1";
    }

    if ( $p{type} ) {
        $p{where} .= ' AND ' if $p{where};
        $p{where} .= 'page.page_type = ?';
        push @{ $p{bind} }, $p{type};
    }

    my $deleted = '1=1';
    unless ($p{deleted_ok}) {
        $deleted = $p{deleted} ? 'deleted' : 'NOT deleted';
    }

    my $workspace_filter = '';
    my @workspace_ids;
    if ( $p{workspace_ids} ) {
        return [] unless @{$p{workspace_ids}};

        $workspace_filter = '.workspace_id IN ('
            . join( ',', map {'?'} @{ $p{workspace_ids} } ) . ')';
        push @workspace_ids, @{ $p{workspace_ids} };
    }
    elsif (defined $p{workspace_id}) {
        $workspace_filter = '.workspace_id = ?';
        push @workspace_ids, $p{workspace_id};
    }

    if ($p{orphaned}) {
      $p{where} .= ' AND ' if $p{where};
      $p{where} .= ' not exists (select 1 from page_link where page_link.to_page_id = page.page_id and page_link.to_workspace_id = page.workspace_id)';
    }

    my $order_by = '';
    if ($p{order_by} && $p{order_by} =~ /^\S+(:? asc| desc)?$/i) {
        $order_by = "ORDER BY $p{order_by}, page.name asc";
    }

    my $limit = '';
    if ( $p{limit}  && $p{limit} != -1) {
        $limit = 'LIMIT ?';
        push @{ $p{bind} }, $p{limit};
    }

    my $offset = '';
    if ( $p{offset} && $p{offset} != -1) {
        $offset = 'OFFSET ?';
        push @{ $p{bind} }, $p{offset};
    }

    my $page_workspace_filter = $workspace_filter
                                   ? " AND page$workspace_filter"
                                   : '';
    $p{where} = "AND $p{where}" if $p{where};
    my $sth = sql_execute(
        <<EOT,
SELECT $MODEL_FIELDS FROM page 
        JOIN "Workspace" USING (workspace_id)
        $more_join
    WHERE $deleted
      $page_workspace_filter
      $p{where}
    $order_by
    $limit
    $offset
EOT
        @workspace_ids,
        @{ $p{bind} },
    );

    my $pages = $class->load_pages_from_sth($sth, $p{hub});
    return $pages if $p{do_not_need_tags};
    return $pages if @$pages == 0;

    # Fetch all the tags for these pages
    # We will fetch all the page_tag, and then filter out which pages
    # we're interested in ourselves.
    # Alternatively, we could pass Pg in a potentially huge list of page_ids
    # we were interested in.  We ass-u-me this would be slower.
    my %ids;
    for my $p (@$pages) {
        $p->{tags} = [];
        my $key = "$p->{workspace_id}-$p->{page_id}";
        $ids{$key} = $p;
    }
    my $pagetag_workspace_filter = $workspace_filter
                                     ? " WHERE page_tag$workspace_filter"
                                     : '';
    $sth = sql_execute( <<EOT, @workspace_ids );
SELECT workspace_id, page_id, tag 
    FROM page_tag 
    $pagetag_workspace_filter
EOT
    my $data = $sth->fetchall_arrayref;
    for my $row (@$data) {
        my $key = "$row->[0]-$row->[1]";
        if ( my $page = $ids{$key} ) {
            push @{ $page->{tags} }, $row->[2];
        }
    }

    return $pages;
}

sub load_pages_from_sth {
    my $class = shift;
    my $sth = shift;
    my $hub = shift;
    return [
        map { Socialtext::Model::Page->new_from_row($_) }
        map { $_->{hub} = $hub; $_ } @{ $sth->fetchall_arrayref({}) }
    ];
}

sub Minimal_by_name {
    my $class        = shift;
    my $t            = time_scope 'Minimal_by_name';
    my %p            = @_;
    my $workspace_id = $p{workspace_id};
    my $limit        = $p{limit} || '';
    my $page_filter  = $p{page_filter} or die "page_filter is mandatory!";
    # \m matches beginning of a word
    $page_filter = '\\m' . $page_filter;

    my @bind = ($workspace_id, $page_filter);

    my $and_type = '';
    if ($p{type}) {
        $and_type = 'AND page_type = ?';
        push @bind, $p{type};
    }

    if ($limit) {
        push @bind, $limit;
        $limit = "LIMIT ?";
    }

    my $sth = sql_execute(<<EOT, @bind);
SELECT * FROM (
    SELECT page_id, 
           name, 
           -- _utc suffix is to prevent performance-impacing naming collisions:
           last_edit_time AT TIME ZONE 'UTC' AS last_edit_time_utc, 
           page_type 
      FROM page
     WHERE NOT deleted
       AND workspace_id = ? 
       AND name ~* ?
       $and_type
     ORDER BY last_edit_time DESC
      $limit
) AS X ORDER BY name
EOT

    my $pages = $sth->fetchall_arrayref( {} );
    foreach my $page (@$pages) {
        $page->{last_edit_time} = delete $page->{last_edit_time_utc};
    }
    return $pages;
}

sub ChangedCount {
    my $class        = shift;
    my $t            = time_scope 'ChangedCount';
    my %p            = @_;
    my $workspace_id = $p{workspace_id} or croak "workspace_id needed";
    my $max_age      = $p{duration} or croak "duration needed";

    return sql_singlevalue(<<EOT,
SELECT count(*) FROM page
    WHERE NOT deleted
      AND workspace_id = ?
      AND last_edit_time > ('now'::timestamptz - ?::interval)
EOT
        $workspace_id, "$max_age seconds",
    );
}

sub ActiveCount {
    my ($class, %p) = @_;
    my $t  = time_scope 'ActiveCount';
    my $id = $p{workspace_id} || $p{workspace};

    return sql_singlevalue(q{
        SELECT count(*) FROM page WHERE NOT deleted AND workspace_id = ?
    }, $id);
}

sub TaggedCount {
    my ($class, %p) = @_;
    my $t = time_scope 'TaggedCount';

    return sql_singlevalue(q{
        SELECT count(*) 
          FROM page
          JOIN page_tag USING (page_id, workspace_id)
         WHERE NOT deleted AND workspace_id = ? AND tag = ?
    }, $p{workspace_id}, $p{tag});
}

1;
