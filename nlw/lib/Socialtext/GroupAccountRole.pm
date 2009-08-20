package Socialtext::GroupAccountRole;
# @COPYRIGHT@
use Moose;
use Socialtext::Moose::SqlTable;
use namespace::clean -except => 'meta';

with qw(
    Socialtext::Moose::Has::RoleId
    Socialtext::Moose::Has::AccountId
    Socialtext::Moose::Has::GroupId
);

has_table 'group_account_role';

sub update {
    my ($self, $proto_gar) = @_;
    require Socialtext::GroupAccountRoleFactory;
    Socialtext::GroupAccountRoleFactory->Update($self, $proto_gar);
}

no Moose;
__PACKAGE__->meta->make_immutable;
=head1 NAME

Socialtext::GroupAccountRole - A Group's Role in a specific Account

=head1 SYNOPSIS

  # create a brand new GAR
  $gar = Socialtext::GroupAccountRoleFactory->Create( {
      group_id    => $group_id,
      account_id  => $account_id,
      role_id     => $role_id,
  } );

  # update an existing GAR
  $gar->update( { role_id => $new_role_id } );

=head1 DESCRIPTION

C<Socialtext::GroupAccountRole> provides methods for dealing with the data in
the C<group_account_role> table, representing the Role that a Group may have
in a given Account.  Each object represents a I<single> row from the table.

You will commonly see this object referred to as an "GAR".

=head1 METHODS

=over

=item B<$gar-E<gt>group_id()>

The Group Id.

=item B<$gar-E<gt>group()>

A C<Socialtext::Group> object.

=item B<$gar-E<gt>account_id()>

The Account Id.

=item B<$gar-E<gt>account()>

A C<Socialtext::Account> object.

=item B<$gar-E<gt>role_id()>

The Role Id.

=item B<$gar-E<gt>role()>

A C<Socialtext::Role> object.

=item B<$gar-E<gt>update(\%proto_gar)>

Updates the GAR based on the information in the provided C<\%proto_gar>
hash-ref.

This is simply a helper method which calls
C<Socialtext::GroupAccountRoleFactory->Update($gar,\%proto_gar)>

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
1;
