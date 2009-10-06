package Socialtext::Rest::WorkspaceGroups;
# @COPYRIGHT@
use Moose;
use Socialtext::Workspace;
use Socialtext::HTTP ':codes';
use Socialtext::JSON qw/decode_json/;
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest::Collection';

has 'workspace' => (is => 'rw', isa => 'Maybe[Object]', lazy_build => 1);

sub permission { +{ GET => undef, POST => undef } }
sub allowed_methods { 'POST', 'GET' }
sub collection_name { "Account Groups" }

sub _entities_for_query {
    my $self      = shift;
    my $rest      = $self->rest;
    my $user      = $rest->user;
    my $workspace = $self->workspace or return ();

    my @groups;
    my $group_cursor = $workspace->groups();
    if ($user->is_business_admin) {
        @groups = $group_cursor->all();
    }
    else {
        while (my $g = $group_cursor->next) {
            eval {
                if ($g->creator->user_id == $user->user_id 
                        or $g->has_user($user)) {
                    push @groups, $g;
                }
            };
            warn $@ if $@;
        }
    }

    return @groups;
}

sub _build_workspace {
    my $self = shift;

    return Socialtext::Workspace->new( 
        name => Socialtext::String::uri_unescape( $self->acct ),
    );
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
