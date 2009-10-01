package Socialtext::Rest::Group::Users;
# @COPYRIGHT@
use Moose;
extends 'Socialtext::Rest::Groups';
use Socialtext::Group;
use namespace::clean -except => 'meta';

# Anybody can see these, since they are just the list of workspaces the user
# has 'selected'.
sub permission { +{} }

sub collection_name { 'Group users' }

sub _entities_for_query {
    my $self = shift;
    my $group_id = $self->group_id;
    my $user = $self->rest->user();

    my $group = Socialtext::Group->GetGroup(group_id => $group_id);
    die Socialtext::Exception::NotFound->new() unless $group;

    die Socialtext::Exception::NotFound->new()
        unless $user->is_business_admin
            or $group->creator->user_id == $user->user_id
            or $group->has_user($user);

    my $users = $group->users_as_minimal_arrayref();
    return @$users;
}

sub _entity_hash { return $_[1] }

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 NAME

Socialtext::Rest::Group::Users - List users in a group

=head1 SYNOPSIS

    GET /data/groups/:group_id/users

=head1 DESCRIPTION

View the list of users in the specified group.

=cut
