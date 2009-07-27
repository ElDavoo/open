package Socialtext::Events::Source::WorkspaceConversations;
# @COPYRIGHT@
use Moose;
use Socialtext::SQL qw/:exec/;
use Socialtext::SQL::Builder qw/sql_abstract/;
use Socialtext::Events::Event::Page;
use namespace::clean -except => 'meta';

with 'Socialtext::Events::Source', 'Socialtext::Events::Source::FromDB';

has 'workspace_id' => ( is => 'ro', isa => 'Int', required => 1 );

use constant event_type => 'Socialtext::Events::Event::Page';
use constant query_name => 'convos';

around 'prepare' => sub {
    my $code = shift;
    my $self = shift;

    # decline if the viewer hasn't contributed here
    my $has_contribs = sql_singlevalue(q{
        SELECT 1
        FROM event
        WHERE event_class = 'page' AND is_page_contribution(action)
          AND actor_id = ?
          AND page_workspace_id = ?
        LIMIT 1
    }, $self->viewer_id, $self->workspace_id);
    return unless $has_contribs;

    return $self->$code(@_);
};

sub query_and_binds {
    my $self = shift;

    my @where;
    push @where, \[q{
            event_class = 'page'
            AND is_page_contribution(action)
            AND actor_id <> ?
            AND page_workspace_id = ?
        }, $self->user_id, $self->workspace_id
    ];

    # NOTE: followed is based on the viewer, not the user
    if ($self->filter->followed) {
        push @where, actor_id => [$self->followed_clause, $self->viewer_id];
    }

    # clear things that we can't IS NULL assert:
    $self->filter->clear_actor_id unless $self->filter->actor_id;
    $self->filter->clear_page_id unless $self->filter->page_id;

    push @where, -nest => $self->filter->generate_filter(qw(
        before after actor_id tag_name action page_id
    ));

    push @where, \[q{(
            -- it's in my watchlist
            EXISTS (
                SELECT 1
                FROM "Watchlist" wl
                WHERE wl.workspace_id = ?
                  AND wl.user_id = ?
                  AND event.page_id = wl.page_text_id::text
            )
            OR
            -- i created it
            EXISTS (
                SELECT 1
                FROM page p
                WHERE p.workspace_id = ?
                  AND p.page_id = event.page_id
                  AND p.creator_id = ?
            )
            OR
            -- they contributed to it after i did
            EXISTS (
                SELECT 1
                FROM event my_contribs
                WHERE my_contribs.event_class = 'page'
                  AND is_page_contribution(my_contribs.action)
                  AND my_contribs.page_workspace_id = ?
                  AND my_contribs.page_id = event.page_id
                  AND my_contribs.actor_id = ?
                  AND my_contribs.at < event.at
            )
        )}, ($self->workspace_id, $self->viewer_id) x 3
    ];

    my ($sql, @binds) = sql_abstract()->select(
        'event', $self->columns, \@where, 'at DESC', $self->limit
    );
    return $sql, \@binds;
}

around 'columns' => sub {
    return shift->().', page_id, page_workspace_id';
};

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

Socialtext::Events::Source::WorkspaceConversations - A per-workspace source of page conversation events.

=head1 DESCRIPTION

Provides C<Socialtext::Events::Event::Page> events that are specific to a C<viewer> and a C<workspace_id>.

A page conversation event will show up when the viewer contributes to a wiki
page and then some other user contributes to the same page after that.

The caller is responsible for checking that the C<viewer> has access to each
workspace.

=head1 SYNOPSIS

Use C<construct_source> from a Stream where possible, but you could also
construct this stream directly.

    for my $ws_id (@workspace_ids) {
        my $src = Socialtext::Events::Source::WorkspaceConversations->new(
            workspace_id => $ws_id, # required
            viewer => $current_user,
            filter => ...,
            ...
        );
        push @sources, $src;
    }

