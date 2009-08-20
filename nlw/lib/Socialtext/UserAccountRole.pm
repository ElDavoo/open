package Socialtext::UserAccountRole;
# @COPYRIGHT@
use Moose;
use Socialtext::Moose::SqlTable;
use namespace::clean -except => 'meta';

with qw(
    Socialtext::Moose::Has::RoleId
    Socialtext::Moose::Has::AccountId
    Socialtext::Moose::Has::UserId
);

has_table 'user_account_role';

sub update {
    my ($self, $proto_uar) = @_;
    require Socialtext::UserAccountRoleFactory;
    Socialtext::UserAccountRoleFactory->Update($self, $proto_uar);
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
=head1 NAME

Socialtext::UserAccountRole - A User's Role in a specific Account

=head1 SYNOPSIS

  # create a brand new UAR
  $uar = Socialtext::UserAccountRoleFactory->Create( {
      user_id     => $user_id,
      account_id  => $account_id,
      role_id     => $role_id,
  } );

  # update an existing UAR
  $uar->update( { role_id => $new_role_id } );

=head1 DESCRIPTION

C<Socialtext::UserAccountRole> provides methods for dealing with the data in
the C<user_account_role> table, representing the Role that a User may have in
a given Account.  Each object represents a I<single> row from the table.

You will commonly see this object referred to as an "UAR".

=head1 METHODS

=over

=item B<$uar-E<gt>user_id()>

The User Id.

=item B<$uar-E<gt>user()>

A C<Socialtext::User> object.

=item B<$uar-E<gt>account_id()>

The Account Id.

=item B<$uar-E<gt>account()>

A C<Socialtext::Account> object.

=item B<$uar-E<gt>role_id()>

The Role Id.

=item B<$uar-E<gt>role()>

A C<Socialtext::Role> object.

=item B<$uar-E<gt>update(\%proto_uar)>

Updates the UAR based on the information in the provided C<\%proto_uar>
hash-ref.

This is simply a helper method which calls
C<Socialtext::UserAccountRoleFactory->Update($uar,\%proto_uar)>

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
