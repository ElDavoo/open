package Socialtext::Moose::Has::AccountId;
# @COPYRIGHT@
use Moose::Role;
use Socialtext::Moose::SqlTable::Meta::Attribute::Trait::DbColumn;
use namespace::clean -except => 'meta';

has 'account_id' => (
    is => 'ro', isa => 'Int',
    required => 1,
    writer => '_account_id',
    trigger => \&_set_account_id,
    primary_key => 1,
    traits => [
        'Socialtext::Moose::SqlTable::Meta::Attribute::Trait::DbColumn'
    ],
);

has 'account' => (
    is => 'ro', isa => 'Socialtext::Account',
    lazy_build => 1,
);

sub _set_account_id {
    my $self = shift;
    $self->clear_account();
}

sub _build_account {
    my $self = shift;
    require Socialtext::Account;
    my $account_id = $self->account_id();
    my $account = Socialtext::Account->new( account_id => $account_id );
    unless ($account) {
        die "account_id=$account_id no longer exists";
    }
    return $account;
}

no Moose::Role;
1;
=head1 NAME

Socialtext::Moose::Has::AccountId - A Moose Role for using
C<Socialtext::Account>'s

=head1 SYNOPSIS

    package MyClass;
    use Moose;
    
    with 'Socialtext::Moose::Has::AccountId';

    sub do_something {
        my $self = shift;

        print "not the right account"
            unless ( $self->account->name eq 'The Right Account' );
    }

=head1 DESCRIPTION

C<Socialtext::Moose::Has::AccountId> provides us with easy access to a
C<Socialtext::Account> object, provided an C<account_id>.

This will set up the Moose Metadata to use the C<account_id> param passed to
the C<new()> method of the comsuming object to have a C<primary_key> trait.

=head1 METHODS

=over

=item B<$object-E<gt>account_id()>

Accessor for the C<account_id> param passed to new.

=item B<$object-E<gt>account()>

Accessor for the C<Socialtext::Account> object described by C<account_id>.

=back

=head1 COPYRIGHT & LICENSE

Copyright (C) 2009 Socialtext, Inc., All Rights Reserved.

=head1 SEE ALSO

L<Socialtext::Moose::SqlTable::Meta::Attribute::Trait::DbColumn>.

=cut
