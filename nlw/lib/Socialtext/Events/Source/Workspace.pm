package Socialtext::Events::Source::Workspace;
# @COPYRIGHT@
use Moose;
use Socialtext::SQL::Builder qw/sql_abstract/;
use Socialtext::Events::Event::Page;
use namespace::clean -except => 'meta';

with 'Socialtext::Events::Source', 'Socialtext::Events::Source::FromDB';

has 'workspace_id' => ( is => 'ro', isa => 'Int', required => 1 );

use constant event_type => 'Socialtext::Events::Event::Page';
use constant query_name => 'workspace';

sub query_and_binds {
    my $self = shift;

    $self->filter->clear_page_workspace_id;
    $self->filter->clear_not_page_workspace_id;
    $self->filter->clear_account_id;
    $self->filter->clear_not_account_id;

    my @where = (
        \"event_class = 'page'",
        ($self->filter->contributions ? \"is_page_contribution(action)" : ()),
        'page_workspace_id' => $self->workspace_id,
    );

    push @where, -nest => $self->filter->generate_standard_filter();

    if ($self->filter->followed) {
        push @where, actor_id => \[$self->followed_clause, $self->viewer_id];
    }

    my $sa = sql_abstract();
    my ($sql, @binds) = $sa->select(
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

Socialtext::Events::Source::Workspace - A per-workspace source of page events.

=head1 DESCRIPTION

Provides C<Socialtext::Events::Event::Page> events on a per-workspace basis.

The caller is responsible for checking that the C<viewer> has access to each
workspace.

=head1 SYNOPSIS

Use C<construct_source> from a Stream where possible, but you could also
construct this stream directly.

    for my $ws_id (@workspace_ids) {
        my $src = Socialtext::Events::Source::Workspace->new(
            workspace_id => $ws_id, # required
            viewer => $current_user,
            filter => ...,
            ...
        );
        push @sources, $src;
    }

