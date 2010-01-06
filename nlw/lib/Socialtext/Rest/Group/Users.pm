package Socialtext::Rest::Group::Users;
# @COPYRIGHT@
use Moose;
extends 'Socialtext::Rest::Groups';
use Socialtext::Group;
use Socialtext::HTTP ':codes';
use Socialtext::JSON qw/decode_json/;
use Socialtext::Permission qw/ST_READ_PERM ST_ADMIN_PERM/;
use Socialtext::User;
use Socialtext::JobCreator;
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

    my $can_read = $group->user_can(
        user => $user,
        permission => ST_READ_PERM,
    );
    die Socialtext::Exception::NotFound->new()
        unless $user->is_business_admin
            or $group->creator->user_id == $user->user_id
            or $can_read;

    my $users = $group->users_as_minimal_arrayref();

    # XXX: We should sort in the DB, but the GroupSearch role doesn't seem
    # easily extendible for me to implement it there.
    return sort { $a->{best_full_name} cmp $b->{best_full_name} } @$users;
}

sub _entity_hash { return $_[1] }

sub POST_json {
    my $self    = shift;
    my $rest    = shift;
    my $invitor = $rest->user;
    my $data    = decode_json($rest->getContent());

    my $group = Socialtext::Group->GetGroup( group_id => $self->group_id );
    unless ( $group ) {
        $rest->header( -status => HTTP_404_Not_Found );
        return 'Resource not found';
    }

    # Group is not Socialtext sourced, we don't control its membership.
    unless ( $group->can_update_store ) {
        $rest->header( -status => HTTP_400_Bad_Request );
        return 'Group membership cannot be changed';
    }

    my $can_admin = $group->user_can(
        user       => $invitor,
        permission => ST_ADMIN_PERM
    );
    unless ($self->user_can('is_business_admin') || $can_admin) {
        $rest->header( -status => HTTP_401_Unauthorized );
        return '';
    }

    $data = _parse_data($data);

    unless (defined $data) {
        $rest->header( -status => HTTP_400_Bad_Request );
        return '';
    }

    # Build a list of user roles so we can check for problems before we
    # actually add the roles
    my @user_roles;
    for my $roledata (@{ $data->{users} }) {
        my $username = $roledata->{username};

        my $name_or_id = $roledata->{user_id} || $roledata->{username};
        unless ( $name_or_id ) {
            $rest->header( -status => HTTP_400_Bad_Request );
            return 'Missing a username or user_id';
        }

        my $invitee = eval { Socialtext::User->Resolve($name_or_id) };
        unless ( $invitee ) {
            $rest->header( -status => HTTP_400_Bad_Request );
            return "User with $name_or_id does not exist";
        }

        my $role_name = $roledata->{role_name} || 'member';
        my $role = Socialtext::Role->new( name => $role_name );
        unless ( $role && $role->name ) {
            $rest->header( -status => HTTP_400_Bad_Request );
            return "Invalid role name $role_name";
        }

        my $role_for_user = $group->role_for_user($invitee);
        if ($role_for_user && $role_for_user->name eq $role_name) {
            $rest->header( -status => HTTP_400_Bad_Request );
            return "User $name_or_id already has Role $role_name";
        }

        push @user_roles, [$invitee, $role];
    }

    for my $to_add (@user_roles) {
        $group->add_user(user => $to_add->[0], role => $to_add->[1]);
        if ($data->{send_message}) {
            Socialtext::JobCreator->insert(
                'Socialtext::Job::GroupInvite',
                {   
                    group_id   => $group->group_id,
                    user_id    => $to_add->[0]->user_id,
                    sender_id  => $invitor->user_id,
                    $data->{additional_message}
                        ?  (extra_text => $data->{additional_message}) : (),
                },
            );
        }
    }

    $rest->header( -status => HTTP_201_Created );
    return '';
}

sub _parse_data {
    my $data = shift;

    return unless defined $data;

    # This is the "new" format, it's a hashref with users index.
    if (ref($data) eq 'HASH' && $data->{users}) {
        $data->{send_message} ||= 0;
        return $data;
    }

    warn "deprecated JSON passed to /data/groups/:group_id/users\n";

    # Support posting a single user, or an array of users
    my $users = (ref($data) eq 'HASH') ? [$data] : $data;

    # We still may have passed bad data, return if we don't have an arrayref
    # at this point.
    return undef unless ref($users) eq 'ARRAY';

    return +{
        users        => $users,
        send_message => 0,
    };
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
