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

__END__

=head1 NAME

Socialtext::Events::Stream::HasPages - Stream role to incorporate standard
wiki page events.

=head1 DESCRIPTION

This role appends a list of C<Socialtext::Events::Source::Workspace> Sources
to the stream via C<_build_sources()>.

Does C<Socialtext::Events::Stream::HasWorkspaces>.

=head1 SYNOPSIS

    package MyStream;
    use Moose;
    extends 'Socialtext::Events::Stream';
    with 'Socialtext::Events::Stream::HasPages';
    ...
    my $e = $self->next(); # could return a Socialtext::Events::Event::Page

=head1 SEE ALSO

C<Socialtext::Events::Stream>
