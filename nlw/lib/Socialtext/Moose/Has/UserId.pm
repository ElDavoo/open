package Socialtext::Moose::Has::UserId;
# @COPYRIGHT@
use Moose::Role;
use namespace::clean -except => 'meta';

has 'user_id' => (
    is => 'rw', isa => 'Int',
    writer => '_user_id',
    trigger => \&_set_user_id,
    primary_key => 1,
    traits => [
        'Socialtext::Moose::SqlTable::Meta::Attribute::Trait::DbColumn'
    ],
);

has 'user' => (
    is => 'ro', isa => 'Socialtext::User',
    lazy_build => 1,
);

sub _set_user_id {
    my $self = shift;
    $self->clear_user();
}

sub _build_user {
    my $self = shift;
    require Socialtext::User;           # lazy-load
    my $user_id = $self->user_id();
    my $user    = Socialtext::User->new(user_id => $user_id);
    unless ($user) {
        die "user_id=$user_id no longer exists";
    }
    return $user;
}

no Moose::Role;
1;
=head1 NAME

Socialtext::Moose::Has::UserId - A Moose Role for using
C<Socialtext::User>'s

=head1 SYNOPSIS

    package MyClass;
    use Moose;
    
    with 'Socialtext::Moose::Has::UserId';

    sub do_something {
        my $self = shift;

        print "not the right user"
            unless ( $self->user->name eq 'The Right User' );
    }

=head1 DESCRIPTION

C<Socialtext::Moose::Has::UserId> provides us with easy access to a
C<Socialtext::User> object, provided an C<user_id>.

This will set up the Moose Metadata to use the C<user_id> param passed to
the C<new()> method of the comsuming object to have a C<primary_key> trait.

=head1 METHODS

=over

=item B<$object-E<gt>user_id()>

Accessor for the C<user_id> param passed to new.

=item B<$object-E<gt>user()>

Accessor for the C<Socialtext::User> object described by C<user_id>.

=back

=head1 COPYRIGHT & LICENSE

Copyright (C) 2009 Socialtext, Inc., All Rights Reserved.

=head1 SEE ALSO

L<Socialtext::Moose::SqlTable::Meta::Attribute::Trait::DbColumn>.

=cut
