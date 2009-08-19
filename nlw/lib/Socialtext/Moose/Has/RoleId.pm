package Socialtext::Moose::Has::RoleId;
# @COPYRIGHT@
use Moose::Role;
use Socialtext::Moose::SqlTable::Meta::Attribute::Trait::DbColumn;
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
