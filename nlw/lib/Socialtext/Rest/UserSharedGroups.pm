package Socialtext::Rest::UserSharedGroups;
# @COPYRIGHT@
use Moose;
use Socialtext::User;
use Socialtext::HTTP qw(:codes);
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest::Collection';

# We punt to the permission handling stuff below.
sub permission { +{ GET => undef } }
sub entity_name { "User " . $_[0]->username . " groups" }

sub authorized_to_view {
    my ($self, $user) = @_;
    my $acting_user = $self->rest->user;
    return $user;
}

sub _entities_for_query {
    my $self   = shift;
    my $rest   = $self->rest;
    my $viewer = $rest->user;

    unless ($viewer) {
        $rest->header( -status => HTTP_401_Unauthorized );
        return ();
    }

    my $other = eval { Socialtext::User->Resolve($self->username) };
    die Socialtext::Exception::NotFound->new() unless $other;

    my $group_cursor = $other->groups;
    return $group_cursor->all() if $viewer->is_business_admin;
    
    my @shared_groups;
    while (my $g = $group_cursor->next) {
        push @shared_groups, $g 
            if $g->has_user($viewer) or $g->creator->user_id == $viewer->user_id;
    }

    return @shared_groups;
}

sub _entity_hash {
    my ($self, $group) = @_;
    return $group->to_hash( show_members => $self->{_show_members} );
}

around get_resource => sub {
    my $orig = shift;
    my $self = shift;

    $self->{_show_members} = $self->rest->query->param('show_members') ? 1 : 0;
    return $orig->($self, @_);
};

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
