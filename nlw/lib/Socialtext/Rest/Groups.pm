package Socialtext::Rest::Groups;
# @COPYRIGHT@
use Moose;
use Socialtext::Group;
use Socialtext::HTTP ':codes';
use Socialtext::JSON qw/decode_json encode_json/;
use Socialtext::File;
use Socialtext::SQL ':txn';
use Socialtext::Exceptions;
use Socialtext::Role;
use Socialtext::Permission 'ST_ADMIN_WORKSPACE_PERM';
use Socialtext::JobCreator;
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest::Collection';
with 'Socialtext::Rest::Pageable';

# Anybody can see these, since they are just the list of groups the user
# has 'selected'.
sub permission { +{} }

sub collection_name { 'Groups' }

sub _entity_hash { 
    my ($self, $group) = @_;
    my $show_members = $self->rest->query->param('show_members');
    return $group if $self->rest->query->param('ids_only');
    return {
        group_id => $group->group_id,
        name => $group->name,
        user_count => $group->user_count,
        workspace_count => $group->workspace_count,
        creation_date => $group->creation_datetime->ymd,
        created_by_user_id => $group->created_by_user_id,
        created_by_username => $group->creator->guess_real_name,
        uri => "/data/groups/" . $group->group_id,
        primary_account_id => $group->primary_account_id,
        primary_account_name => $group->primary_account->name,
        description => $group->description,
        permission_set => $group->permission_set,
        $show_members
            ? ( members => $group->users_as_minimal_arrayref('member') )
            : (),
    };
}

sub _get_total_results {
    my $self = shift;
    my $user = $self->rest->user;
    if ($user->is_business_admin and $self->rest->query->param('all')) {
        Socialtext::Group->Count;
    }
    elsif (defined $self->{_total_results}) {
        return $self->{_total_results};
    }
    else {
        return $user->group_count;
    }
}

sub _get_entities {
    my $self = shift;
    my $user = $self->rest->user;
    my $q    = $self->rest->query;

    my $filter = $q->param('q') || $q->param('filter') || '';
    my $discoverable = $q->param('discoverable');
 
    if ($filter) {
        my $group_ids = [
            $user->groups(discoverable => $discoverable, ids_only => 1)->all
        ];

        require Socialtext::Search::Solr::Factory;
        my $searcher = Socialtext::Search::Solr::Factory->create_searcher();
        my ($results, $count) = $searcher->begin_search(
            $filter,
            undef,
            undef,
            doctype   => 'group',
            viewer    => $user,
            limit     => $self->items_per_page, 
            offset    => $self->start_index,
            direction => $self->reverse ? 'desc' : 'asc',
            order     => 'title',
            group_ids => $group_ids,
        );
        $self->{_total_results} = $count;
        return [ map { $_->group } @{ $results->() } ];
    }
    else {
        if ($user->is_business_admin and $self->rest->query->param('all')) {
            my $iter = Socialtext::Group->All(
                order_by => $self->order,
                sort_order => $self->reverse ? 'DESC' : 'ASC',
                include_aggregates => 1,
                creator => 1,
                primary_account => 1,
                limit => $self->items_per_page,
                offset => $self->start_index,
            );
            return [ $iter->all ];
        }
        elsif (defined $self->rest->query->param('startIndex') and not $self->rest->query->param('skipTotalResult')) {
            # We need to supply "total_results".
            my $full_set = [ $user->groups( discoverable => $discoverable )->all ];
            $self->{_total_results} = @$full_set; # XXX - Re-implement this entire paragraph with a Count method.
            splice(@$full_set, 0, $self->start_index) if $self->start_index;
            splice(@$full_set, $self->items_per_page) if @$full_set > $self->items_per_page;
            return $full_set;
        }
        else {
            # Old API; no need to supply total_results.
            return [ $user->groups(
                ids_only => scalar $self->rest->query->param('ids_only'),
                discoverable => $discoverable,
                limit => $self->items_per_page,
                offset => $self->start_index,
            )->all ];
        }
    }
}

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
    my $user = $rest->user;

    unless ($user->is_authenticated && !$user->is_deleted
                && Socialtext::Group->User_can_create_group($user)) {
        $rest->header(-status => HTTP_401_Unauthorized);
        return '';
    }

    my $data = eval { decode_json($rest->getContent()) };
    if ($@) {
        $rest->header(-status => HTTP_400_Bad_Request);
        return "bad json\n";
    }

    unless ($data->{name} || $data->{ldap_dn}) {
        $rest->header(-status => HTTP_400_Bad_Request);
        return "Either ldap_dn or name is required to create a group.";
    }

    unless ( defined $data and ref($data) eq 'HASH' ) {
        $rest->header(-status => HTTP_400_Bad_Request);
        return '';
    }

    my $is_self_join = $data->{permission_set}
        && $data->{permission_set} eq 'self-join';
    if ($is_self_join && $data->{workspaces}) {
        $rest->header(-status => HTTP_400_Bad_Request);
        return 'self-join groups may not contain workspaces';
    }

    $data->{account_id} ||= $user->primary_account_id;

    my $group;
    eval { sql_txn {
        $group = ($data->{ldap_dn})
            ? $self->_create_ldap_group($data)
            : $self->_create_native_group($data);

        $self->_add_members_to_group($group, $data);

        my @created = $self->_create_workspaces($data->{new_workspaces});

        $self->_add_group_to_workspaces(
            $group, @{$data->{workspaces}}, @created);

        if (my $photo_id = $data->{photo_id}) {
            my $blob = scalar Socialtext::File::get_contents_binary(
                "$Socialtext::Rest::Uploads::UPLOAD_DIR/$photo_id");
            $group->photo->set(\$blob);
        }
    }};
    if (my $e = $@) {
        my $status = (ref($e) eq 'Socialtext::Exception::Auth')
            ? HTTP_401_Unauthorized
            : HTTP_400_Bad_Request;

        $rest->header(-status => $status);
        return $e;
    }

    $rest->header(-status => HTTP_201_Created);
    return encode_json($group->to_hash);
}

sub _add_members_to_group {
    my $self    = shift;
    my $group   = shift;
    my $data    = shift;
    my $invitor = $self->rest->user;

    return unless $data and $data->{users};
    die "group is not updateable\n" unless $group->can_update_store;

    my $notify  = $data->{send_message} || 0;
    my $message = $data->{additional_message} || '';

    for my $meta (@{$data->{users}}) {
        my $name_or_id = $meta->{username} || $meta->{user_id};
        my $invitee = Socialtext::User->Resolve($name_or_id)
            or die "no such user\n";

        my $shared_plugin = $invitor->can_use_plugin_with('groups', $invitee);
        die Socialtext::Exception::Auth->new()
            unless $shared_plugin || $invitor->is_business_admin;

        my $role = Socialtext::Role->new(
            name => ($meta->{role}) ? $meta->{role} : 'member' );
        die "no such role: '$meta->{role}'\n" unless $role;

        next if $group->role_for_user($invitee, {direct => 1});

        $group->add_user(
            user  => $invitee,
            role  => $role,
            actor => $invitor,
        );

        if ($notify) {
            Socialtext::JobCreator->insert(
                'Socialtext::Job::GroupInvite',
                {
                    group_id  => $group->group_id,
                    user_id   => $invitee->user_id,
                    sender_id => $invitor->user_id,
                    $message ? (extra_text => $message) : (),
                }
            );
        }
    }
}

sub _create_workspaces {
    my $self      = shift;
    my $to_create = shift;
    my $creator   = $self->rest->user;

    my @ws_meta = ();
    for my $meta (@$to_create) {
        my $ws = Socialtext::Workspace->create(
            name       => $meta->{name},
            title      => $meta->{title},
            account_id => $creator->primary_account_id,
        );

        $ws->add_user(
            user => $creator,
            role => Socialtext::Role->Admin(),
        );

        push @ws_meta, {workspace_id => $ws->workspace_id, role => 'member'};
    }

    return @ws_meta;
}

sub _add_group_to_workspaces {
    my $self    = shift;
    my $group   = shift;
    my @ws_meta = @_;
    my $invitor = $self->rest->user;

    for my $ws (@ws_meta) {
        my $workspace = Socialtext::Workspace->new(
            workspace_id => $ws->{workspace_id}
        ) or die "no such workspace\n";

        my $perm = $workspace->permissions->user_can(
            user       => $invitor,
            permission => ST_ADMIN_WORKSPACE_PERM,
        );
        die Socialtext::Exception::Auth->new()
            unless $perm || $self->rest->user->is_business_admin;

        my $role = Socialtext::Role->new(
            name => ($ws->{role}) ? $ws->{role} : 'member' );
        die "no such role: '$ws->{role}'\n" unless $role;

        if ($group->permission_set eq 'private'
            && $workspace->permissions->current_set_name ne 'member-only'
        ) {
            die Socialtext::Exception::DataValidation->new();
        }

        next if $workspace->role_for_group($group, {direct => 1});

        $workspace->add_group(
            group => $group,
            role  => $role,
            actor => $invitor,
        );
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
        and die "group already exists\n";

    my $group = Socialtext::Group->GetGroup(
        driver_unique_id   => $data->{ldap_dn},
        primary_account_id => $data->{account_id},
    ) or die "ldap group does not exist\n";

    return $group;
}

sub _create_native_group {
    my $self    = shift;
    my $data    = shift;
    my $creator = $self->rest->user;

    Socialtext::Group->GetGroup(
        driver_group_name  => $data->{name},
        primary_account_id => $data->{account_id},
        created_by_user_id => $creator->user_id,
    ) and die "group already exists\n";

    my $group = Socialtext::Group->Create({
        driver_group_name  => $data->{name},
        primary_account_id => $data->{account_id},
        created_by_user_id => $creator->user_id,
        description        => $data->{description},
        permission_set     => $data->{permission_set},
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
