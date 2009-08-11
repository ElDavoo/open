package Socialtext::Moose::SqlBuilder::Role::DoesSqlInsert;

use Moose::Role;
use Socialtext::SQL::Builder qw(sql_abstract);
use Socialtext::SQL qw(sql_execute);

requires 'Sql_table_name';
requires 'Sql_coerce_bindings';

sub SqlInsert {
    my $self  = shift;
    my $proto = shift;

    my $table   = $self->Sql_table_name();
    my $builder = sql_abstract();
    my ($sql, @bindings) = $builder->insert($table, $proto);

    $self->Sql_coerce_bindings(\@bindings);
    return sql_execute($sql, @bindings);
}

no Moose::Role;
1;

=head1 NAME

Socialtext::Moose::SqlBuilder::Role::DoesSqlInsert - SQL INSERT Moose Role

=head1 SYNOPSIS

  $sth = MyFactory->SqlInsert( {
      user_id          => 123,
      driver_key       => 'Default',
      driver_unique_id => 123,
      email_address    => 'john.doe@example.com',
  } );

=head1 DESCRIPTION

C<Socialtext::Moose::SqlBuilder::Role::DoesSqlInsert> implements a C<Moose>
Role which allows for the generation and execution of SQL INSERT statements
against an underlying DB table.

=head1 METHODS

=over

=item B<$class-E<gt>SqlInsert(\%proto)>

Issues a SQL C<INSERT> against the DB, using the field/value pairs defined in
the provided C<\%proto> hash-ref.  Returns a DBI Statement Handle back to the
caller.

=back

=head1 COPYRIGHT & LICENSE

Copyright (C) 2009 Socialtext, Inc., All Rights Reserved.

=head1 SEE ALSO

L<Socialtext::Moose::SqlBuilder>.

=cut
