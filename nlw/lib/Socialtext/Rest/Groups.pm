package Socialtext::Rest::Groups;
# @COPYRIGHT@
use Moose;
extends 'Socialtext::Rest::Collection';
use Socialtext::Group;
use Socialtext::HTTP ':codes';
use Socialtext::JSON qw/decode_json encode_json/;
use Socialtext::File;
use Socialtext::SQL ':txn';
use Socialtext::Exceptions;
use Socialtext::Role;
use Socialtext::Permission 'ST_ADMIN_WORKSPACE_PERM';
use namespace::clean -except => 'meta';

# Anybody can see these, since they are just the list of groups the user
# has 'selected'.
sub permission { +{} }

sub collection_name { 'Groups' }

sub _entities_for_query {
    my $self = shift;
    my $user = $self->rest->user();

    if ($user->is_business_admin and $self->rest->query->param('all')) {
        return Socialtext::Group->All->all;
    }

    return $user->groups->all;
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

sub POST_json {
    my $self = shift;
    my $rest = shift;

    unless ($self->rest->user->is_authenticated) {
        $rest->header(-status => HTTP_401_Unauthorized);
        return '';
    }

    my $data = eval { decode_json($rest->getContent()) };
    if ($@) {
        $rest->header(-status => HTTP_400_Bad_Request);
        return "Bad JSON: $@";
    }

    unless ($data->{name} || $data->{ldap_dn}) {
        $rest->header(-status => HTTP_400_Bad_Request);
        return "Either ldap_dn or name is required to create a group.";
    }

    unless ( defined $data and ref($data) eq 'HASH' ) {
        $rest->header(-status => HTTP_400_Bad_Request);
        return '';
    }

    $data->{account_id} ||= $self->rest->user->primary_account_id;

    sql_begin_work();
    my $group;
    eval {
        $group = ($data->{ldap_dn})
            ? $self->_create_ldap_group($data)
            : $self->_create_native_group($data);

        if (my $workspaces = $data->{workspaces}) {
            $self->_add_group_to_workspaces($group, $workspaces);
        }

        if (my $photo_id = $data->{photo_id}) {
            my $blob = scalar Socialtext::File::get_contents_binary(
                "$Socialtext::Rest::Uploads::UPLOAD_DIR/$photo_id");
            $group->photo->set(\$blob);
        }
    };
    if (my $e = $@) {
        sql_rollback();

        my $status = (ref($e) eq 'Socialtext::Exception::Auth')
            ? HTTP_401_Unauthorized
            : HTTP_400_Bad_Request;

        $rest->header(-status => $status);
        return '';
    }
    sql_commit();

    $rest->header(-status => HTTP_201_Created);
    return encode_json($group->to_hash);
}

sub _add_group_to_workspaces {
    my $self       = shift;
    my $group      = shift;
    my $workspaces = shift;

    for my $ws (@$workspaces) {
        my $workspace = Socialtext::Workspace->new(
            workspace_id => $ws->{workspace_id});

        my $perm = $workspace->permissions->user_can(
            user       => $self->rest->user,
            permission => ST_ADMIN_WORKSPACE_PERM,
        );
        
        die Socialtext::Exception::Auth->new()
            unless $perm || $self->rest->user->is_business_admin;

        my $role = Socialtext::Role->new(
            name => ($ws->{role}) ? $ws->{role} : 'member' );

        $workspace->add_group(group => $group, role => $role);
    }
}

sub _create_ldap_group {
    my $self    = shift;
    my $data    = shift;
    my $rest    = $self->rest;
    my $ldap_dn = $data->{ldap_dn};

    die Socialtext::Exception::Auth->new()
        unless $rest->user->is_business_admin;

    Socialtext::Group->GetProtoGroup(driver_unique_id => $ldap_dn)
        and die "Group already exists";

    my $group = Socialtext::Group->GetGroup(
        driver_unique_id   => $data->{ldap_dn},
        primary_account_id => $data->{account_id},
    ) or die "ldap group does not exist";

    return $group;
}

sub _create_native_group {
    my $self = shift;
    my $data = shift;

    my $group = Socialtext::Group->Create({
        driver_group_name => $data->{name},
        primary_account_id => $data->{account_id},
        created_by_user_id => $self->rest->user->user_id,
        description => $data->{description},
    });

    return $group;
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 NAME

Socialtext::Rest::Groups - List groups on the system.

=head1 SYNOPSIS

    GET /data/groups

=head1 DESCRIPTION

View the list of groups.  You can only see groups you created or are a
member of, unless you are a business admin, in which case you can see
all groups.

=cut
