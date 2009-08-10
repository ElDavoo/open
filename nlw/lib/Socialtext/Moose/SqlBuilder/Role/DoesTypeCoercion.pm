package Socialtext::Moose::SqlBuilder::Role::DoesTypeCoercion;

use Moose::Role;
use Socialtext::SQL qw(:time);

sub Sql_coerce_bindings {
    my $class         = shift;
    my $bindings_aref = shift;
    map {
        if (UNIVERSAL::isa($_, 'DateTime')) {
            $_ = sql_format_timestamptz($_);
        }
    } @{$bindings_aref};
}

no Moose::Role;
1;

=head1 NAME

Socialtext::Moost::SqlBuilder::Role::DoesTypeCoercion - Type coercion for Pg

=head1 SYNOPSIS

  $self->Sql_coerce_bindings(\@bindings);

=head1 DESCRIPTION

C<Socialtext::Moost::SqlBuilder::Role::DoesTypeCoercion> implements a method
to assist with type coercion for SQL parameter bindings, when dealing with
I<non-Moose> objects (presumably, if you've got a Moose object, you've already
set it up with proper type coercions).

=head1 METHODS

=over

=item B<$self-E<gt>Sql_coerce_bindings(\@bindings)>

Coerces the provided list-ref of C<\@bindings> B<inline>, so that the types
match up properly with something that we're going to hand off to the
underlying PostgreSQL database.

=back

=head1 COPYRIGHT & LICENSE

Copyright (C) 2009 Socialtext, Inc., All Rights Reserved.

=head1 SEE ALSO

L<Socialtext::Moose::SqlBuilder>.

=cut
