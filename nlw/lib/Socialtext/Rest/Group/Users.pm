package Socialtext::Rest::Group::Users;
# @COPYRIGHT@
use Moose;
extends 'Socialtext::Rest::Groups';
use Socialtext::Group;
use Socialtext::HTTP ':codes';
use Socialtext::JSON qw/decode_json/;
use Socialtext::Permission qw/ST_READ_PERM ST_ADMIN_PERM/;
use Socialtext::User::Find::Container;
use Socialtext::User;
use Socialtext::JobCreator;
use Socialtext::l10n qw(loc);
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest::Users';

has 'group' => (is => 'ro', isa => 'Maybe[Socialtext::Group]', lazy_build => 1);
has 'user_is_related' => (is => 'ro', isa => 'Bool', lazy_build => 1);
# see builder for definition of "visitor"
has 'user_is_visitor' => (is => 'ro', isa => 'Bool', lazy_build => 1);

sub _build_group {
    my $self = shift;

    my $group_id = $self->group_id;
    my $group = Socialtext::Group->GetGroup(group_id => $group_id);
    return $group;
}

sub _build_user_is_related {
    my $self = shift;
    return $self->hub->authz->user_sets_share_an_account(
        $self->rest->user, $self->group);
}

sub _build_user_is_visitor {
    my $self = shift;
    my $visitor = $self->rest->user;
    my $group = $self->group;

    # visitor is a user related to this group by some account that is doing
    # some self-join related activity.

    return if $group->has_user($visitor);
    return if $group->permission_set ne 'self-join';
    return $self->user_is_related;
}

# Anybody can see these, since they are just the list of workspaces the user
# has 'selected'.
sub permission { +{} }

sub collection_name { 'Group users' }

sub if_authorized {
    my $self = shift;
    my $method = shift;
    my $call = shift;
    my $user = $self->rest->user;

    return $self->not_authorized if $user->is_guest;

    return $self->no_resource('group') unless $self->group;

    my $perm;
    if    ($method eq 'GET')  { $perm = ST_READ_PERM; }
    elsif ($method eq 'POST') { $perm = ST_ADMIN_PERM; }
    else { return $self->bad_method; }

    my $can = $self->group->user_can(
        user => $user,
        permission => $perm,
    );

    $can ||= $self->user_is_visitor;

    unless ($can || $user->is_business_admin) {
        return $self->user_is_related
            ? $self->not_authorized
            : $self->no_resource('group');
    }

    return $self->$call(@_);
}

sub _build_user_find {
    my $self = shift;
    my $group = $self->group;
    my $viewer = $self->rest->user;
    my $q = $self->rest->query;

    my %args = (
        viewer    => $viewer,
        limit     => $self->items_per_page,
        offset    => $self->start_index,
        container => $group,
        direct    => $q->param('direct') || undef,
        order     => $q->param('order') || '',
        reverse   => $q->param('reverse') || undef,
        # these may get changed by 'just_visiting':
        filter    => $q->param('filter') || undef,
        all       => $q->param('all') || undef,
        minimal   => $q->param('minimal') || 0,
    );

    $args{just_visiting} = 1 if $self->user_is_visitor;

    return Socialtext::User::Find::Container->new(\%args);
}

sub POST_json {
    my $self    = shift;
    my $rest    = shift;
    my $invitor = $rest->user;
    my $data    = decode_json($rest->getContent());

    my $group = $self->group;
    unless ( $group ) {
        $rest->header( -status => HTTP_404_Not_Found );
        return 'Resource not found';
    }

    # Group is not Socialtext sourced, we don't control its membership.
    unless ( $group->can_update_store ) {
        $rest->header( -status => HTTP_400_Bad_Request );
        return 'Group membership cannot be changed';
    }

    my $is_visiting = $self->user_is_visitor;

    my $can_admin = ($is_visiting) ? undef : $group->user_can(
        user       => $invitor,
        permission => ST_ADMIN_PERM
    );
    my $is_badmin = $self->user_can('is_business_admin');
    unless ($is_badmin || $can_admin || $is_visiting) {
        $rest->header( -status => HTTP_403_Forbidden );
        return 'Insufficient privileges to make this change to the group';
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
            return loc('Missing a username or user_id');
        }

        my $invitee = eval { Socialtext::User->Resolve($name_or_id) };
        unless ( $invitee ) {
            $rest->header( -status => HTTP_400_Bad_Request );
            return loc("User [_1] does not exist",$name_or_id);
        }

        my $role_name = $roledata->{role_name} || 'member';
        if ($is_visiting and not $is_badmin) {
            if ($role_name ne 'member') {
                $rest->header( -status => HTTP_400_Bad_Request );
                return loc("Can only become member of self-join groups");
            }
        }

        my $role = Socialtext::Role->new( name => $role_name );
        unless ( $role && $role->name ) {
            $rest->header( -status => HTTP_400_Bad_Request );
            return loc("Invalid Role name '[_1]'.", $role_name);
        }

        my $role_for_user = $group->role_for_user($invitee);
        if ($role_for_user) {
            $rest->header( -status => HTTP_400_Bad_Request );
            return loc("User '[_1]' already has the Role of '[_2]' in this Group.", $invitee->guess_real_name, $role_for_user->name);
        }

        push @user_roles, [$invitee, $role];
    }

    for my $to_add (@user_roles) {
        $group->add_user(
            user  => $to_add->[0],
            role  => $to_add->[1],
            actor => $invitor,
        );
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
