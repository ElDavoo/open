# @COPYRIGHT@
package Socialtext::UserWorkspaceRole;

use Moose;
use Socialtext::Moose::SqlTable;

# These will go away soon enough.
use Socialtext::SQL qw( sql_execute sql_convert_to_boolean );
use Socialtext::Exceptions qw( rethrow_exception );

use namespace::clean -except => 'meta';

our $VERSION = '0.02';

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

sub get {
    my ( $class, %args ) = @_;

    my $sth;
    my $sql = 'select * from "UserWorkspaceRole" where';
    my $connector = '';
    my @params = ();
    if ($args{workspace_id}) {
        $sql .= " $connector workspace_id = ?";
        $connector = 'and';
        push @params, $args{workspace_id};
    }
    if ($args{user_id}) {
        $sql .= " $connector user_id = ?";
        $connector = 'and';
        push @params, $args{user_id};
    }
    $sth = sql_execute($sql, @params);

    my $row = $sth->fetchrow_hashref();
    return undef if (!defined($row));

    return $class->_new_from_hash_ref($row);
}

sub _new_from_hash_ref {
    my ( $class, $row ) = @_;
    return $row unless $row;
    return bless $row, $class;
}

sub create {
    my $class = shift;
    my %p = @_;

    my $self;

    my @params = ();
    my $sql = 'insert into "UserWorkspaceRole" (';
    my $connector = '';
    foreach ('workspace_id', 'user_id', 'role_id', 'is_selected') {
        $sql .= "$connector $_";
        $connector = ', ';
        my $value = $p{$_};
        $value = sql_convert_to_boolean($p{$_}, 't') if ($_ eq 'is_selected');
        push @params, $value;
    }
    $sql .= ') values (';
    $sql .= join(',', map {'?'} @params);
    $sql .= ')';

    sql_execute($sql, @params);

    return $class->_new_from_hash_ref(\%p);
}

sub delete {
    my $self = shift;

    my $sql =
        'delete from "UserWorkspaceRole"'.
        ' where workspace_id = ? and user_id = ?';
    sql_execute($sql, $self->workspace_id, $self->user_id);
}

sub update {
    my $self = shift;
    my $p    = shift;

    my $sql =
        'update "UserWorkspaceRole" '.
        ' set role_id = ?, is_selected = ? where workspace_id = ? and user_id = ?';
    sql_execute($sql, $p->{role_id}, sql_convert_to_boolean($p->{is_selected}), $self->workspace_id, $self->user_id);

    foreach my $attr ( qw/role_id is_selected/ ) {
        $self->meta->find_attribute_by_name($attr)->set_value(
            $self, $p->{$attr},
        );
    }
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

=item Socialtext::UserWorkspaceRole->_new_from_hash_ref(hash)

Returns a new instantiation of the UWR object. Data members for the object
are initialized from the hash reference passed to the method.

=back

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
