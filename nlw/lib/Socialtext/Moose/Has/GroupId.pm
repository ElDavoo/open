package Socialtext::Moose::Has::GroupId;
# @COPYRIGHT@
use Moose::Role;
use Socialtext::Moose::SqlTable::Meta::Attribute::Trait::DbColumn;
use namespace::clean -except => 'meta';

has 'group_id' => (
    is => 'rw', isa => 'Int',
    writer => '_group_id',
    trigger => \&_set_group_id,
    primary_key => 1,
    traits => [
        'Socialtext::Moose::SqlTable::Meta::Attribute::Trait::DbColumn'
    ],
);

has 'group' => (
    is => 'ro', isa => 'Socialtext::Group',
    lazy_build => 1,
);

sub _set_group_id {
    my $self = shift;
    $self->clear_group();
}

sub _build_group {
    my $self = shift;
    require Socialtext::Group;          # lazy-load
    my $group_id = $self->group_id();
    my $group    = Socialtext::Group->GetGroup(group_id => $group_id);
    unless ($group) {
        die "group_id=$group_id no longer exists";
    }
    return $group;
}

no Moose::Role;
1;
=head1 NAME

Socialtext::Moose::Has::GroupId - A Moose Role for using
C<Socialtext::Group>'s

=head1 SYNOPSIS

    package MyClass;
    use Moose;
    
    with 'Socialtext::Moose::Has::GroupId';

    sub do_something {
        my $self = shift;

        print "not the right group"
            unless ( $self->group->name eq 'The Right Group' );
    }

=head1 DESCRIPTION

C<Socialtext::Moose::Has::GroupId> provides us with easy access to a
C<Socialtext::Group> object, provided an C<group_id>.

This will set up the Moose Metadata to use the C<group_id> param passed to
the C<new()> method of the comsuming object to have a C<primary_key> trait.

=head1 METHODS

=over

=item B<$object-E<gt>group_id()>

Accessor for the C<group_id> param passed to new.

=item B<$object-E<gt>group()>

Accessor for the C<Socialtext::Group> object described by C<group_id>.

=back

=head1 COPYRIGHT & LICENSE

Copyright (C) 2009 Socialtext, Inc., All Rights Reserved.

=head1 SEE ALSO

L<Socialtext::Moose::SqlTable::Meta::Attribute::Trait::DbColumn>.

=cut
