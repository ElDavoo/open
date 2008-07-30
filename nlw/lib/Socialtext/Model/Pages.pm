package Socialtext::Model::Pages;
# @COPYRIGHT@
use strict;
use warnings;
use Socialtext::Model::Page;
use Socialtext::SQL qw/sql_execute/;
use Socialtext::Timer;
use Carp qw/croak/;

sub By_seconds_limit {
    my $class         = shift;
    my %p             = @_;
    my $since         = $p{since};
    my $seconds       = $p{seconds};
    my $workspace_ids = $p{workspace_ids};
    my $workspace_id  = $p{workspace_id};
    my $limit         = $p{count} || $p{limit};
    my $tag           = $p{tag} || $p{category};
    my $hub           = $p{hub};

    Socialtext::Timer->Start('By_seconds_limit');
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

    my $pages = $class->_fetch_pages(
        hub => $hub,
        $workspace_ids ? ( workspace_ids => $workspace_ids ) : (),
        where        => $where,
        limit        => $limit,
        tag          => $tag,
        bind         => \@bind,
        order_by     => 'page.last_edit_time',
        workspace_id => $workspace_id,
    );
    Socialtext::Timer->Stop('By_seconds_limit');
    return $pages;
}

sub All_active {
    my $class        = shift;
    my %p            = @_;
    my $hub          = $p{hub};
    my $limit        = $p{count} || $p{limit};
    my $workspace_id = $p{workspace_id};

    Socialtext::Timer->Start('All_active');
    my $pages = $class->_fetch_pages(
        hub          => $hub,
        limit        => $limit,
        workspace_id => $workspace_id,
    );
    Socialtext::Timer->Stop('All_active');
    return $pages;
}

sub By_tag {
    my $class        = shift;
    my %p            = @_;
    my $hub          = $p{hub};
    my $workspace_id = $p{workspace_id};
    my $limit        = $p{count} || $p{limit};
    my $tag          = $p{tag};

    Socialtext::Timer->Start('By_category');
    my $pages = $class->_fetch_pages(
        hub          => $hub,
        workspace_id => $workspace_id,
        limit        => $limit,
        tag          => $tag,
        order_by     => 'page.last_edit_time',
    );
    Socialtext::Timer->Stop('By_category');
    return $pages;
}

sub By_id {
    my $class            = shift;
    my %p                = @_;
    my $hub              = $p{hub};
    my $workspace_id     = $p{workspace_id};
    my $page_id          = $p{page_id};
    my $do_not_need_tags = $p{do_not_need_tags};

    my $where;
    my $bind;
    if (ref($page_id) eq 'ARRAY') {
        $where = 'page_id IN (' 
            . join(',', map { '?' } @$page_id) . ')';
        $bind = $page_id;
    }
    else {
        $where = 'page_id = ?';
        $bind = [$page_id];
    }

    Socialtext::Timer->Continue('By_id');
    my $pages = $class->_fetch_pages(
        hub              => $hub,
        workspace_id     => $workspace_id,
        where            => $where,
        bind             => $bind,
        do_not_need_tags => $do_not_need_tags,
    );
    die "No page found for ($workspace_id, $page_id)" unless @$pages;
    Socialtext::Timer->Pause('By_id');
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
        do_not_need_tags => 0,
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

    my $workspace_filter = '';
    my @workspace_ids;
    if ( $p{workspace_ids} ) {
        $workspace_filter = '.workspace_id IN ('
            . join( ',', map {'?'} @{ $p{workspace_ids} } ) . ')';
        push @workspace_ids, @{ $p{workspace_ids} };
    }
    elsif ($p{workspace_id}) {
        $workspace_filter = '.workspace_id = ?';
        push @workspace_ids, $p{workspace_id} 
                ? $p{workspace_id}
                : $p{hub} ? $p{hub}->current_workspace->workspace_id
                          : die "No workspace filter supplied";
    }

    my $order_by = '';
    if ( $p{order_by} ) {
        $order_by = "ORDER BY $p{order_by} DESC";
    }

    my $limit = '';
    if ( $p{limit} ) {
        $limit = 'LIMIT ?';
        push @{ $p{bind} }, $p{limit};
    }

    my $page_workspace_filter = $workspace_filter
                                   ? " AND page$workspace_filter"
                                   : '';
    $p{where} = "AND $p{where}" if $p{where};
    my $sth = sql_execute(
        <<EOT,
SELECT page.workspace_id, 
       "Workspace".name AS workspace_name, 
       page.page_id, 
       page.name, 
       page.last_editor_id AS last_editor_id,
       editor.username AS last_editor_username, 
       page.last_edit_time AT TIME ZONE 'GMT' AS last_edit_time, 
       page.creator_id,
       creator.username AS creator_username, 
       page.create_time AT TIME ZONE 'GMT' AS create_time, 
       page.current_revision_id, 
       page.current_revision_num, 
       page.revision_count, 
       page.page_type, 
       page.deleted, 
       page.summary
    FROM page 
        JOIN "Workspace" USING (workspace_id)
        JOIN "UserId" editor_id  ON (page.last_editor_id = editor_id.system_unique_id)
        JOIN "User"   editor     ON (editor_id.driver_unique_id = editor.user_id)
        JOIN "UserId" creator_id ON (page.creator_id     = creator_id.system_unique_id)
        JOIN "User"   creator    ON (creator_id.driver_unique_id = creator.user_id)
        $more_join
    WHERE page.deleted = ?::bool
      $page_workspace_filter
      $p{where}
    $order_by
    $limit
EOT
        $p{deleted},
        @workspace_ids,
        @{ $p{bind} },
    );

    my @pages = map { Socialtext::Model::Page->new_from_row($_) }
        map { $_->{hub} = $p{hub}; $_ } @{ $sth->fetchall_arrayref( {} ) };
    return \@pages if $p{do_not_need_tags};

    # Fetch all the tags for these pages
    # We will fetch all the page_tag, and then filter out which pages
    # we're interested in ourselves.
    # Alternatively, we could pass Pg in a potentially huge list of page_ids
    # we were interested in.  We ass-u-me this would be slower.
    my %ids;
    for my $p (@pages) {
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
    while ( my $row = $sth->fetchrow_arrayref ) {
        next unless $row;
        my $key = "$row->[0]-$row->[1]";
        if ( my $page = $ids{$key} ) {
            push @{ $page->{tags} }, $row->[2];
        }
    }

    return \@pages;
}

1;
