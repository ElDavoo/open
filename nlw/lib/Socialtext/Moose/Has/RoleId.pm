package Socialtext::Moose::Has::RoleId;
# @COPYRIGHT@
use Moose::Role;
use namespace::clean -except => 'meta';

has 'role_id' => (
    is => 'rw', isa => 'Int',
    writer => '_role_id',
    trigger => \&_set_role_id,
    required => 1,
    traits => [
        'Socialtext::Moose::SqlTable::Meta::Attribute::Trait::DbColumn'
    ],
);

has 'role' => (
    is => 'ro', isa => 'Socialtext::Role',
    lazy_build => 1,
);

sub _set_role_id {
    my $self = shift;
    $self->clear_role();
}

sub _build_role {
    my $self    = shift;
    require Socialtext::Role;           # lazy-load
    my $role_id = $self->role_id();
    my $role    = Socialtext::Role->new(role_id => $role_id);
    unless ($role) {
        die "role_id=$role_id no longer exists";
    }
    return $role;
}

no Moose::Role;
1;

=head1 NAME

Socialtext::Moose::Has::RoleId - A Moose Role for using
C<Socialtext::Role>'s

=head1 SYNOPSIS

    package MyClass;
    use Moose;
    
    with 'Socialtext::Moose::Has::RoleId';

    sub do_something {
        my $self = shift;

        print "not the right role"
            unless ( $self->role->name eq 'The Right Role' );
    }

=head1 DESCRIPTION

C<Socialtext::Moose::Has::RoleId> provides us with easy access to a
C<Socialtext::Role> object, provided an C<role_id>.

This will set up the Moose Metadata to use the C<role_id> param passed to
the C<new()> method of the comsuming object to have a C<primary_key> trait.

=head1 METHODS

=over

=item B<$object-E<gt>role_id()>

Accessor for the C<role_id> param passed to new.

=item B<$object-E<gt>role()>

Accessor for the C<Socialtext::Role> object described by C<role_id>.

=back

=head1 COPYRIGHT & LICENSE

Copyright (C) 2009 Socialtext, Inc., All Rights Reserved.

=head1 SEE ALSO

L<Socialtext::Moose::SqlTable::Meta::Attribute::Trait::DbColumn>.

=cut
