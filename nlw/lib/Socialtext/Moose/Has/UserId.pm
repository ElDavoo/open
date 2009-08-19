package Socialtext::Moose::Has::UserId;
# @COPYRIGHT@
use Moose::Role;
use Socialtext::Moose::SqlTable::Meta::Attribute::Trait::DbColumn;
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
