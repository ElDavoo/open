package Socialtext::Moose::ObjectFactory;
# @COPYRIGHT@

use Moose::Role;
use namespace::clean -except => 'meta';

with qw(
    Socialtext::Moose::SqlBuilder
    Socialtext::Moose::SqlBuilder::Role::DoesSqlInsert
    Socialtext::Moose::SqlBuilder::Role::DoesSqlSelect
    Socialtext::Moose::SqlBuilder::Role::DoesSqlUpdate
    Socialtext::Moose::SqlBuilder::Role::DoesSqlDelete
    Socialtext::Moose::SqlBuilder::Role::DoesColumnFiltering
    Socialtext::Moose::SqlBuilder::Role::DoesTypeCoercion
);

requires 'Builds_sql_for';

sub Get {
    my ($self, %p) = @_;

    # Only concern ourselves with valid Db Columns
    my $where = $self->FilterValidColumns( \%p );

    # Fetch the record from the DB
    my $sth = $self->SqlSelectOneRecord( { where => $where } );
    my $row = $sth->fetchrow_hashref();
    return unless $row;

    # Create an instance of the object based on the row we got back
    my $class = $self->Builds_sql_for();
    return $class->new($row);
}

sub Cursor {
    my $self_or_class = shift;
    my $sth           = shift;
    my $closure       = shift;
    my $target_class  = $self_or_class->Builds_sql_for();

    eval  "require $target_class";
    die $@ if $@;

    return Socialtext::MultiCursor->new(
        iterables => [ $sth->fetchall_arrayref( {} ) ],
        apply     => sub {
            my $row      = shift;
            my $instance = $target_class->new($row);
            return ( $closure ) ? $closure->($instance) : $instance;
        },
    );
}

no Moose::Role;
1;

=head1 NAME

Socialtext::Moose::ObjectFactory - ObjectFactory Role for SQL stored objects

=head1 SYNOPSIS

  package MyFactory;
  use Moose;
  with qw(
      Socialtext::Moose::ObjectFactory
  );
  ...

=head1 DESCRIPTION

C<Socialtext::Moose::ObjectFactory> provides a baseline Role for a Factory to
create objects that are stored in a SQL DB.

=head1 METHODS

=over

=item B<$class-E<gt>Get(PARAMS)>

Looks for an existing record in the underlying DB table matching the given
PARAMS, and returns an instantiated object representing that row, or C<undef>
if it can't find a match.

=item B<$self_or_class-E<gt>Cursor($sth, \&coderef)>

Returns a C<Socialtext::MultiCursor> to iterate over all of the result records
in the given DBI C<$sth>, by turning each one of the result rows into an
actual I<instance> of the class that the Factory generating objects of (the
same one it C<Builds_sql_for>).

This method takes an optional C<\&coderef> that can be used to manipulate the
instantiated objects prior to them getting returned.

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
