package Socialtext::Moose::Has::WorkspaceId;
# @COPYRIGHT@
use Moose::Role;
use namespace::clean -except => 'meta';

has 'workspace_id' => (
    is => 'rw', isa => 'Int',
    writer => '_workspace_id',
    trigger => \&_set_workspace_id,
    primary_key => 1,
    traits => [
        'Socialtext::Moose::SqlTable::Meta::Attribute::Trait::DbColumn'
    ],
);

has 'workspace' => (
    is => 'ro', isa => 'Socialtext::Workspace',
    lazy_build => 1,
);

sub _set_workspace_id {
    my $self = shift;
    $self->clear_workspace();
}

sub _build_workspace {
    my $self = shift;
    require Socialtext::Workspace;      # lazy-load
    my $ws_id     = $self->workspace_id();
    my $workspace = Socialtext::Workspace->new(workspace_id => $ws_id);
    unless ($workspace) {
        die "workspace_id=$ws_id no longer exists";
    }
    return $workspace;
}

no Moose::Role;
1;
=head1 NAME

Socialtext::Moose::Has::WorkspaceId - A Moose Role for using
C<Socialtext::Workspace>'s

=head1 SYNOPSIS

    package MyClass;
    use Moose;
    
    with 'Socialtext::Moose::Has::WorkspaceId';

    sub do_something {
        my $self = shift;

        print "not the right account"
            unless ( $self->account->name eq 'The Right Workspace' );
    }

=head1 DESCRIPTION

C<Socialtext::Moose::Has::WorkspaceId> provides us with easy access to a
C<Socialtext::Workspace> object, provided an C<workspace_id>.

This will set up the Moose Metadata to use the C<workspace_id> param passed to
the C<new()> method of the comsuming object to have a C<primary_key> trait.

=head1 METHODS

=over

=item B<$object-E<gt>workspace_id()>

Accessor for the C<workspace_id> param passed to new.

=item B<$object-E<gt>workspace()>

Accessor for the C<Socialtext::Workspace> object described by C<workspace_id>.

=back

=head1 COPYRIGHT & LICENSE

Copyright (C) 2009 Socialtext, Inc., All Rights Reserved.

=head1 SEE ALSO

L<Socialtext::Moose::SqlTable::Meta::Attribute::Trait::DbColumn>.

=cut
