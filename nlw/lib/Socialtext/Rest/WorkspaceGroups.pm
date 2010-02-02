package Socialtext::Rest::WorkspaceGroups;
# @COPYRIGHT@
use Moose;
use Socialtext::Workspace;
use Socialtext::HTTP ':codes';
use Socialtext::JSON qw/decode_json/;
use Socialtext::Permission 'ST_ADMIN_WORKSPACE_PERM';
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest::Collection';
with 'Socialtext::Rest::Pageable';

has 'workspace' => (is => 'rw', isa => 'Maybe[Object]', lazy_build => 1);

sub permission { +{ GET => undef, POST => undef } }
sub allowed_methods { 'POST', 'GET' }
sub collection_name { "Workspace Groups" }

sub if_authorized {
    my $self = shift;
    my $method = shift;
    my $call = shift;

    my $has_perm = $self->workspace->permissions->user_can(
        user => $self->rest->user,
        permission => ST_ADMIN_WORKSPACE_PERM,
    );
    unless ($has_perm or $self->rest->user->is_business_admin) {
        return $self->not_authorized;
    }

    return $self->$call(@_);
}

sub _get_total_results {
    my $self = shift;
    return $self->workspace->total_group_roles(
        include_aggregates => 1,
        limit => $self->items_per_page,
        offset => $self->start_index,
        direct => 1,
    );
}

sub _get_entities {
    my $self = shift;
    my $rest = shift;

    my $roles = $self->workspace->sorted_group_roles(
        include_aggregates => 1,
        limit => $self->items_per_page,
        offset => $self->start_index,
        direct => 1,
        order_by => 'driver_group_name',
    );
    $roles->apply(sub {
        my $info = shift;
        my $group = Socialtext::Group->GetGroup(group_id => $info->{group_id});
        my $role = Socialtext::Role->new(role_id => $info->{role_id});
        return {
            group_id => $group->group_id,
            group_name => $group->driver_group_name,
            user_count => $info->{user_count},
            workspace_count => $info->{workspace_count},
            primary_account_name => $group->primary_account->name,
            primary_account_id => $group->primary_account->account_id,
            created => $group->creation_datetime->dmy,
            created_by_user_id => $group->created_by_user_id,
            created_by_username => $group->creator->guess_real_name,
            role_id => $info->{role_id},
            role_name => $role->name,
            name => $group->driver_group_name,
            uri => "/data/groups/$info->{group_id}"
        };
    });
    my @groups = $roles->all;
    return \@groups;
}

sub _entity_hash { return $_[1] }

sub _build_workspace {
    my $self = shift;

    return Socialtext::Workspace->new( 
        name => Socialtext::String::uri_unescape( $self->acct ),
    );
}

sub POST_json {
    my $self = shift;
    my $rest = shift;
    my $data = decode_json( $rest->getContent() );

    unless ($self->user_can('is_business_admin')) {
        $rest->header(
            -status => HTTP_401_Unauthorized,
        );
        return '';
    }

    my $workspace = $self->workspace;
    unless ( defined $workspace ) {
        $rest->header(
            -status => HTTP_404_Not_Found,
        );
        return '';
    }

    unless ( defined $data and ref($data) eq 'HASH' ) {
        $rest->header(
            -status => HTTP_400_Bad_Request,
        );
        return '';
    }

    my $group_id = $data->{group_id};
    unless ($group_id) {
        $rest->header(
            -status => HTTP_400_Bad_Request,
        );
        return "Missing a group_id";
    }

    my $group = Socialtext::Group->GetGroup(group_id => $group_id);
    unless ($group) {
        $rest->header(
            -status => HTTP_400_Bad_Request,
        );
        return "Group_id ($group_id) is not a valid group";
    }

    my $role;
    if (my $role_name = $data->{role_name}) {
        $role = Socialtext::Role->new(name => $role_name);
        unless ($role) {
            $rest->header(
                -status => HTTP_400_Bad_Request,
            );
            return "Role ($role_name) is not a valid role";
        }
    }

    if ($workspace->has_group($group)) {
        $rest->header(
            -status => HTTP_409_Conflict,
        );
        return "Group_id ($group_id) is already in this workspace.";
    }

    $workspace->add_group(
        group => $group,
        ($role ? (role => $role) : ()),
    );

    $rest->header(
        -status => HTTP_204_No_Content,
    );
    return '';
}

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
1;

=head1 NAME

Socialtext::Rest::WorkspaceGroups - Groups in a workspace.

=head1 SYNOPSIS

    GET /data/workspaces/:ws/groups

    POST /data/workspaces/:ws/groups as application/json
    - Body should be a JSON hash containing a group_id and optionally a role_name.

=head1 DESCRIPTION

Every Socialtext workspace has a collection of zero or more groups
associated with it. At the URI above, it is possible to view a list of those
groups.

=cut
