package Socialtext::Rest::Group::Users;
# @COPYRIGHT@
use Moose;
extends 'Socialtext::Rest::Groups';
use Socialtext::Group;
use Socialtext::HTTP ':codes';
use Socialtext::JSON qw/decode_json/;
use Socialtext::User;
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

sub POST_json {
    my $self = shift;
    my $rest = shift;
    my $data = decode_json( $rest->getContent() );

    # Only a Business Admin has permission to do this right now.
    unless ($self->user_can('is_business_admin')) {
        $rest->header( -status => HTTP_401_Unauthorized );
        return '';
    }

    unless ( defined $data and ref($data) eq 'HASH' ) {
        $rest->header( -status => HTTP_400_Bad_Request );
        return '';
    }

    my $group = Socialtext::Group->GetGroup( group_id => $self->group_id );
    die Socialtext::Exception::NotFound->new() unless $group;

    # Group is not Socialtext sourced, we don't control its membership.
    unless ( $group->can_update_store ) {
        $rest->header( -status => HTTP_400_Bad_Request );
        return '';
    }

    my $username = $data->{username};
    unless ( $username ) {
        $rest->header( -status => HTTP_400_Bad_Request );
        return 'Missing a username';
    }

    my $user = Socialtext::User->new( username => $username );
    unless ( $user ) {
        $rest->header( -status => HTTP_400_Bad_Request );
        return "User with $username does not exist";
    }

    # Note: We only have 'member' roles for Groups for now.
    my $role_name = $data->{role_name} || 'member';
    my $role = Socialtext::Role->new( name => $role_name );
    unless ( $role && $role->name eq 'member' ) {
        $rest->header( -status => HTTP_400_Bad_Request );
        return "Invalid role name $role_name";
    }

    my $role_for_user = $group->role_for_user( user => $user );
    if ($role_for_user && $role_for_user->name eq $role_name) {
        $rest->header( -status => HTTP_400_Bad_Request );
        return "User $username already has Role $role_name";
    }

    $group->add_user( user => $user, role => $role );

    $rest->header( -status => HTTP_201_Created );
    return '';
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 NAME

Socialtext::Rest::Group::Users - List users in a group

=head1 SYNOPSIS

    GET /data/groups/:group_id/users
    POST /data/groups/:group_id/users

=head1 DESCRIPTION

Manage the list of users in the specified group.

=cut
