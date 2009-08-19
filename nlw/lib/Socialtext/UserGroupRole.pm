package Socialtext::UserGroupRole;
# @COPYRIGHT@
use Moose;
use Socialtext::Moose::SqlTable;
use namespace::clean -except => 'meta';

with qw(
    Socialtext::Moose::Has::RoleId
    Socialtext::Moose::Has::GroupId
    Socialtext::Moose::Has::UserId
);

has_table 'user_group_role';

sub update {
    my ($self, $proto_ugr) = @_;
    require Socialtext::UserGroupRoleFactory;
    Socialtext::UserGroupRoleFactory->Update($self, $proto_ugr);
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Socialtext::UserGroupRole - A User's Role in a specific Group

=head1 SYNOPSIS

  # create a brand new UGR
  $ugr = Socialtext::UserGroupRoleFactory->Create( {
      user_id   => $user_id,
      group_id  => $group_id,
      role_id   => $role_id,
  } );

  # update an existing UGR
  $ugr->update( { role_id => $new_role_id } );

=head1 DESCRIPTION

C<Socialtext::UserGroupRole> provides methods for dealing with the data in the
C<user_group_role> table, representing the Role that a User may have in a
given Group.  Each object represents a I<single> row from the table.

You will commonly see this object referred to as an "UGR", which rhymes with
"booger" (but without the B).

=head1 METHODS

=over

=item B<$ugr-E<gt>user_id()>

The User Id.

=item B<$ugr-E<gt>user()>

A C<Socialtext::User> object.

=item B<$ugr-E<gt>group_id()>

The Group Id.

=item B<$ugr-E<gt>group()>

A C<Socialtext::Group> object.

=item B<$ugr-E<gt>role_id()>

The Role Id.

=item B<$ugr-E<gt>role()>

A C<Socialtext::Role> object.

=item B<$ugr-E<gt>update(\%proto_ugr)>

Updates the UGR based on the information in the provided C<\%proto_ugr>
hash-ref.

This is simply a helper method which calls
C<Socialtext::UserGroupRoleFactory->Update($ugr,\%proto_ugr)>

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
