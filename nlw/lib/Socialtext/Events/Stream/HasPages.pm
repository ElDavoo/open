package Socialtext::Events::Stream::HasPages;
# @COPYRIGHT@
use Moose::Role;
use Socialtext::Events::Source::Workspace;
use namespace::clean -except => 'meta';

with 'Socialtext::Events::Stream::HasWorkspaces';

requires 'construct_source';
requires '_build_sources';

around '_build_sources' => sub {
    my $code = shift;
    my $self = shift;
    my $sources = $self->$code;

    for my $workspace_id (@{ $self->workspace_ids }) {
        push @$sources, $self->construct_source(
            'Socialtext::Events::Source::Workspace',
            workspace_id => $workspace_id
        );
    }

    return $sources;
};

1;
