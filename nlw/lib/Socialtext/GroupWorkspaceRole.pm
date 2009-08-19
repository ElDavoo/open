package Socialtext::GroupWorkspaceRole;
# @COPYRIGHT@
use Moose;
use Socialtext::Moose::SqlTable;
use namespace::clean -except => 'meta';

with qw(
    Socialtext::Moose::Has::RoleId
    Socialtext::Moose::Has::WorkspaceId
    Socialtext::Moose::Has::GroupId
);

has_table 'group_workspace_role';

sub update {
    my ($self, $proto_gwr) = @_;
    require Socialtext::GroupWorkspaceRoleFactory;
    Socialtext::GroupWorkspaceRoleFactory->Update($self, $proto_gwr);
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Socialtext::GroupWorkspaceRole - A Group's Role in a specific Workspace

=head1 SYNOPSIS

  # create a brand new GWR
  $gwr = Socialtext::GroupWorkspaceRoleFactory->Create( {
      group_id     => $group_id,
      workspace_id => $workspace_id,
      role_id      => $role_id,
  } );

  # update an existing GWR
  $gwr->update( { role_id => $new_role_id } );

=head1 DESCRIPTION

C<Socialtext::GroupWorkspaceRole> provides methods for dealing with the data
in the C<group_workspace_role> table, representing the Role that a Group may
have in a given Workspace.  Each object represents a I<single> row from the
table.

You will commonly see this object referred to as a "GWR" (yes, its a "gwar").

=head1 METHODS

=over

=item B<$gwr-E<gt>group_id()>

The Group Id.

=item B<$gwr-E<gt>group()>

A C<Socialtext::Group> object.

=item B<$gwr-E<gt>workspace_id()>

The Workspace Id.

=item B<$gwr-E<gt>workspace()>

A C<Socialtext::Workspace> object.

=item B<$gwr-E<gt>role_id()>

The Role Id.

=item B<$gwr-E<gt>role()>

A C<Socialtext::Role> object.

=item B<$gwr-E<gt>update(\%proto_gwr)>

Updates the GWR based on the information in the provided C<\%proto_gwr>
hash-ref.

This is simply a helper method which calls
C<Socialtext::GroupWorkspaceRoleFactory->Update($gwr,\%proto_gwr)>

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
