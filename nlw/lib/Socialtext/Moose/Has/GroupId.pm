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
