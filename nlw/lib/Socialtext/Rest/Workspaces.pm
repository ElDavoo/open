package Socialtext::Rest::Workspaces;
# @COPYRIGHT@

use warnings;
use strict;

use base 'Socialtext::Rest::Collection';

use Socialtext::JSON;
use Socialtext::HTTP ':codes';
use Socialtext::Permission;
use Socialtext::SQL ':txn';
use Socialtext::Workspace;
use Socialtext::Account;
use Socialtext::Exceptions;
use Socialtext::User;
use Socialtext::Group;
use Socialtext::Permission 'ST_ADMIN_PERM';
use Socialtext::JobCreator;

# Anybody can see these, since they are just the list of workspaces the user
# has 'selected'.
sub permission { +{} }

sub _initialize {
    my ( $self, $rest, $params ) = @_;

    $self->SUPER::_initialize($rest, $params);

    $self->{FilterParameters}->{'title_filter'} = 'title';
}


sub collection_name {
    'Workspaces';
}

sub _entities_for_query {
    my $self = shift;

    my $query = $self->rest->query->param('q');
    my $user  = $self->rest->user();

    # REVIEW: 'all' should only work for some super authenticate user,
    # but which one? business admin seems right
    if ( defined $query and $query eq 'all' and $user->is_business_admin() )
    {
        return ( Socialtext::Workspace->All()->all() );
    }
    else {
        return ( $self->rest->user->workspaces()->all() );
    }
}

sub _entity_hash {
    my $self      = shift;
    my $workspace = shift;

    return +{
        name  => $workspace->name,
        uri   => '/data/workspaces/' . $workspace->name,
        title => $workspace->title,
        # not really modified time, but it is the time we have
        modified_time => $workspace->creation_datetime,
        default => $workspace->is_default ? 1 : 0,
        account_id => $workspace->account_id,
        user_count => $workspace->user_count(direct => 1),
        group_count => $workspace->group_count(direct => 1),

        # workspace_id is the 'right' name for this field, but hang on to 'id'
        # for backwards compatibility.
        workspace_id => $workspace->workspace_id,
        id => $workspace->workspace_id,

        # REVIEW: more?
    };
}

sub POST {
    my $self = shift;
    my $rest = shift;
    my $user = $rest->user;

    unless ($user->is_authenticated && !$user->is_deleted) {
        $rest->header(-status => HTTP_401_Unauthorized);
        return '';
    }

    my $request = decode_json( $rest->getContent() );
    $request = ref($request) eq 'HASH' ? [$request] : $request;
    unless (ref($request) eq 'ARRAY') {
        $rest->header(
            -status => HTTP_400_Bad_Request,
            -type  => 'text/plain', );
        return "bad json";
    }

    sql_begin_work();
    eval {
        for my $meta (@$request) {
            my $ws = $self->_create_workspace_from_meta($meta);

            $ws->add_user(
                user  => $user,
                role  => Socialtext::Role->Admin(),
                actor => $user,
            );
        }
    };
    if (my $e = $@) {
        sql_rollback();
        my ($status, $message);
        if (ref($e)) {
            $status = $e->isa('Socialtext::Exception::Auth')
                ? HTTP_401_Unauthorized
                : HTTP_400_Bad_Request;

            $message = join("\n", $e->message);
        }
        else {
            $status  = HTTP_400_Bad_Request;
            $message = $e;
            warn $message;
        }
        $rest->header(
            -status => $status,
            -type   => 'text/plain',
        );
        return "$message";
    }

    sql_commit();
    $rest->header(
        -status => HTTP_201_Created,
        -type   => 'application/json',
    );
    return 'created';

}

sub _create_workspace_from_meta {
    my $self  = shift;
    my $meta  = shift;
    my $actor = $self->rest->user;

    die Socialtext::Exception::DataValidation->new('name, title required')
        unless $meta->{name} and $meta->{title};

    $meta->{account_id} ||= $actor->primary_account_id;
    my $acct = Socialtext::Account->new(account_id => $meta->{account_id});
    die Socialtext::Exception::Auth->new('user cannot access account')
        unless $actor->is_business_admin || $acct->role_for_user($actor);

    Socialtext::Workspace->new(name => $meta->{name})
        and die Socialtext::Exception::Conflict->new('workspace exists');

    my $ws = Socialtext::Workspace->create(
        creator                         => $actor,
        name                            => $meta->{name},
        title                           => $meta->{title},
        account_id                      => $meta->{account_id},
        cascade_css                     => $meta->{cascade_css},
        customjs_name                   => $meta->{customjs_name},
        customjs_uri                    => $meta->{customjs_uri},
        skin_name                       => $meta->{skin_name},
        show_welcome_message_below_logo =>
            $meta->{show_welcome_message_below_logo},
        show_title_below_logo => $meta->{show_title_below_logo},
        header_logo_link_uri  => $meta->{header_logo_link_uri},

        ( $meta->{clone_pages_from} 
            ? ( clone_pages_from => $meta->{clone_pages_from} )
            : () ),
    );

    if (my $groups = $meta->{groups}) {
        $self->_add_groups_to_workspace($ws, $groups);
    }

    return $ws;
}

sub _add_groups_to_workspace {
    my $self    = shift;
    my $ws      = shift;
    my $groups  = shift;
    my $rest    = $self->rest;
    my $creator = $rest->user;

    $groups = ref($groups) eq 'HASH' ? [$groups] : $groups;
    die Socialtext::Exceptions::DataValidation->new('bad json')
        unless ref($groups) eq 'ARRAY';

    for my $meta (@$groups) {
        my $group = Socialtext::Group->GetGroup(
            group_id => $meta->{group_id}
        ) or die Socialtext::Exception::NotFound->new('group does not exist');

        $ws->has_group($group, {direct => 1})
            and die Socialtext::Exception::Conflict->new(
                'group already in workspace');

        $group->user_can(
            user => $creator,
            permission => ST_ADMIN_PERM,
        ) or die Socialtext::Exception::Auth->new('user is not group admin');

        my $role = Socialtext::Role->new(
            name => $group->{role} ? $group->{role} : 'member'
        ) or die Socialtext::Exception::Param->new('invalid role for group');

        $ws->add_group(
            group => $group,
            role  => $role,
            actor => $creator,
        );
    }

    return undef;
}

1;
