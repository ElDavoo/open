package Socialtext::Events::Stream::HasPages;
# @COPYRIGHT@
use Moose::Role;
use Socialtext::Events::Source::Workspace;
use namespace::clean -except => 'meta';

with 'Socialtext::Events::Stream::HasWorkspaces';

requires 'add_sources';

after 'add_sources' => sub {
    my $self = shift;
    my $sources = shift;

    for my $workspace_id (@{ $self->workspace_ids }) {
        push @$sources, $self->construct_source(
            'Socialtext::Events::Source::Workspace',
            workspace_id => $workspace_id
        );
    }
};

1;
