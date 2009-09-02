package Socialtext::UserWorkspaceRole;
# @COPYRIGHT@
use Moose;
use Socialtext::Moose::SqlTable;
use namespace::clean -except => 'meta';

with qw(
    Socialtext::Moose::Has::RoleId
    Socialtext::Moose::Has::WorkspaceId
    Socialtext::Moose::Has::UserId
);

has_column is_selected => (
    is => 'ro', isa => 'Bool',
    is_required => 1,
);

has_table '"UserWorkspaceRole"';

sub update {
    my $self  = shift;
    my $proto = shift;

    require Socialtext::UserWorkspaceRoleFactory;
    Socialtext::UserWorkspaceRoleFactory->Update($self, $proto);
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

Socialtext::UserWorkspaceRole - A user's role in a specific workspace

=head1 SYNOPSIS

  my $uwr = Socialtext::UserWorkspaceRole->get(
      user_id      => $user_id,
      workspace_id => $workspace_id,
  );

=head1 DESCRIPTION

This class provides methods for dealing with data from the
UserWorkspaceRole table. Each object represents a single row from the
table.

=head1 METHODS

=over 4

=item Socialtext::UserWorkspaceRole->get(PARAMS)

Looks for an existing UserWorkspaceRole matching PARAMS and returns a
C<Socialtext::UserWorkspaceRole> object representing that row if it
exists.

PARAMS I<must> be:

=over 8

=item * user_id => $user_id

=item * workspace_id => $workspace_id

=back

=item Socialtext::UserWorkspaceRole->create(PARAMS)

Attempts to create a role with the given information and returns a new
C<Socialtext::UserWorkspaceRole> object representing the new role.

PARAMS can include:

=over 8

=item * user_id - required

=item * workspace_id - required

=item * role_id - required

=item * is_selected - defaults to 0

=back

=item $uwr->update

Update the DB record with new role and is_selected values.

=over 4

=item $uwr->user_id()

=item $uwr->workspace_id()

=item $uwr->role_id()

=item $uwr->is_selected()

Returns the corresponding attribute for the object.

=back

=item $uwr->delete()

Deletes the object from the DBMS.

=back

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2005-2006 Socialtext, Inc., All Rights Reserved.

=cut
