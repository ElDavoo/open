package Socialtext::Moose::Does::WorkspaceSearch;

use Moose::Role;

requires 'Cursor';
requires 'SqlSelect';
requires 'SqlSortOrder';    # can we pass the buck here to Builds_sql_for?

sub ByWorkspaceId {
    my $self_or_class = shift;
    my $workspace_id  = shift;
    my $closure       = shift;
    my $order         = shift; 

    my $join;

    if ($order) {
        if ($self_or_class->isa('Socialtext::GroupWorkspaceRoleFactory')) {
            $join = 'JOIN groups USING (group_id)';
        }
        elsif ($self_or_class->isa('Socialtext::UserWorkspaceRoleFactory')) {
            $join = 'JOIN users USING (user_id)';
        }
    }
    
    my $sth = $self_or_class->SqlSelect( {
        where => { workspace_id => $workspace_id },
        order => $order || $self_or_class->SqlSortOrder(),
        ($join ? (join => $join) : ()),
    } );
    return $self_or_class->Cursor($sth, $closure);
}

no Moose::Role;
1;

=head1 NAME

Socialtext::Moose::Does::WorkspaceSearch - Moose Role for searching by Workspace

=head1 SYNOPSIS

  package MyClass;
  use Moose;
  with qw(
    Socialtext::Moose::ObjectFactory
    Socialtext::Moose::Does::WorkspaceSearch
  );

  sub Cursor {
  }

=head1 DESCRIPTION

C<Socialtext::Moose::Does::WorkspaceSearch> encapsulates methods used for
searching the underlying DB table by Workspaces.

=head1 METHODS

=over

=item B<$self_or_class-E<gt>ByWorkspaceId($workspace_id, \&coderef)>

Searches the underlying DB table for records by Workspace Id, returning a
C<Socialtext::MultiCursor> containing objects for each of the result records.

An optional C<\&coderef> can be passed through, which can be used to
manipulate the result object before it gets handed back by
C<Socialtext::MultiCursor-E<gt>next()>.

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
