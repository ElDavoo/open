package Socialtext::Rest::Groups;
# @COPYRIGHT@
use Moose;
extends 'Socialtext::Rest::Collection';
use Socialtext::Group;
use namespace::clean -except => 'meta';

# Anybody can see these, since they are just the list of workspaces the user
# has 'selected'.
sub permission { +{} }

sub collection_name { 'Groups' }

sub _entities_for_query {
    my $self = shift;
    my $user = $self->rest->user();

    my $group_cursor = Socialtext::Group->All();
    if ($user->is_business_admin) {
        return $group_cursor->all;
    }

    my @groups;
    while (my $g = $group_cursor->next) {
        eval {
            if ($g->creator->user_id == $user->user_id 
                    or $g->has_user($user)) {
                push @groups, $g;
            }
        };
        warn $@ if $@;
    }
    return @groups;
}

sub _entity_hash {
    my $self  = shift;
    my $group = shift;

    return $group->to_hash( show_members => $self->{_show_members} );
}

around get_resource => sub {
    my $orig = shift;
    my $self = shift;

    $self->{_show_members} = $self->rest->query->param('show_members') ? 1 : 0;
    return $orig->($self, @_);
};

override extra_headers => sub {
    my $self = shift;
    my $resource = shift;

    return (
        '-cache-control' => 'private',
    );
};


__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
