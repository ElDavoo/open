package Socialtext::Rest::Group;
# @COPYRIGHT@
use Moose;
use Socialtext::HTTP ':codes';
use Socialtext::JSON;
use Socialtext::l10n qw(loc);
use Socialtext::Permission qw(ST_READ_PERM ST_ADMIN_PERM
                              ST_ADMIN_WORKSPACE_PERM);
use Socialtext::Exceptions qw(conflict);
use Socialtext::Group;
use Socialtext::Rest::SetController;

use Socialtext::SQL ':txn';
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest::Entity';

has 'group' => (
    is => 'ro', isa => 'Maybe[Socialtext::Group]',
    lazy_build => 1,
);
sub _build_group {
    my $self = shift;
    return eval { Socialtext::Group->GetGroup(group_id => $self->group_id) };
}

has 'controller' => (
    is => 'ro', isa => 'Socialtext::Rest::SetController',
    lazy_build => 1,
);
sub _build_controller {
    my $self = shift;
    return Socialtext::Rest::SetController->new(
        actor     => $self->rest->user,
        container => $self->group,
    );
}

sub permission      { +{} }
sub allowed_methods {'GET, PUT'}
sub entity_name     { "Group" }

sub get_resource {
    my( $self, $rest ) = @_;

    my $group = $self->group;
    return undef unless $group;

    my $can_read = $group->user_can(
        user => $self->rest->user,
        permission => ST_READ_PERM,
    );
    my $user = $self->rest->user;
    if ($user->is_business_admin or $can_read) {
        return $group->to_hash(
            show_members => $rest->query->param('show_members') ? 1 : 0,
            show_admins => $rest->query->param('show_admins') ? 1 : 0,
        );
    }
    return undef;
}

sub create_error {
    my ($self, $err, $group_name) = @_;
    warn $err;
    if ($err =~ m/duplicate key violates/) {
        $self->rest->header( -status => HTTP_409_Conflict );
        return "Error updating group: $group_name already exists.";
    }
    $self->rest->header( -status => HTTP_400_Bad_Request );
    $err =~ s{ at /\S+ line .*}{};
    return "Error updating group: $err";
}

sub PUT_json { $_[0]->_with_admin_permission_do(sub {
    my $self = shift;
    my $rest = $self->rest;
    my $group = $self->group;

    my $data  = eval { decode_json( $rest->getContent ) };

    if (!$data or ref($data) ne 'HASH') {
        $rest->header( -status => HTTP_400_Bad_Request );
        return 'Content should be a JSON hash.';
    }
    unless ($data->{name}) {
        $rest->header( -status => HTTP_400_Bad_Request );
        return 'Name is required';
    }

    eval {
        $group->update_store({
            driver_group_name => $data->{name},
            description => $data->{description} || "",
            permission_set => $data->{permission_set},
        });
    };
    return $self->create_error($@, $data->{name}) if $@;

    my $photo_id = $data->{photo_id};
    if (defined $photo_id) {
        if ($photo_id) {
            eval {
                my $blob = scalar Socialtext::File::get_contents_binary(
                    "$Socialtext::Rest::Uploads::UPLOAD_DIR/$photo_id"
                );
                $group->photo->set(\$blob);
            };
            warn "Error setting profile photo: $@" if $@;
        }
        else {
            $group->photo->purge;
        }
    }

    $self->rest->header(-status => HTTP_202_Accepted);
    return '';
}) }

sub _has_request_error {
    my $self = shift;
    my %p    = (
        permissions => undef,
        @_
    );
    my $rest  = $self->rest;
    my $user  = $rest->user;
    my $group = $self->group;

    return +{
        status  => HTTP_404_Not_Found,
        message => loc('Group not found')
    } unless ($group);

    my $user_has_permission = 0;
    for my $perm (@{ $p{permissions} }) {
        my $can = $group->user_can(
            user       => $user,
            permission => $perm
        );
        $user_has_permission = 1 if $can;
    };
    return +{
        status  => HTTP_403_Forbidden,
        message => loc('You do not have permission')
    } unless ($user_has_permission || $user->is_business_admin);

    return +{
        status => HTTP_400_Bad_Request,
        message => loc('Group membership cannot be changed'),
    } unless $group->can_update_store;

    return undef;
}

sub _with_admin_permission_do {
    my ($self, $callback) = @_;

    my $error = $self->_has_request_error(
        permissions => [ST_ADMIN_PERM]
    );
    if ($error) {
        $self->rest->header(-status => $error->{status});
        return $error->{message};
    }

    local $@;
    return $self->$callback();
}

sub _admin_with_group_data_do_txn {
    my ($self, $callback) = @_;
    $self->_with_admin_permission_do(sub {
        my $group = $self->group;
        my $data  = eval{ decode_json($self->rest->getContent) };
        $data = (ref($data) eq 'HASH') ? [$data] : $data;

        unless ($data) {
            $self->rest->header(-status => HTTP_400_Bad_Request);
            return loc('Malformed JSON passed to resource');
        }

        my $rv = eval { sql_txn {$self->$callback($group, $data)} };

        my $e = Exception::Class->caught('Socialtext::Exception::Conflict');
        if ($e) {
            return $self->SUPER::conflict($e->errors);
        }
        elsif ($e = $@) {
            $self->rest->header(-status => HTTP_400_Bad_Request);
            $e = $1 if $e =~ /(.*) at /;
            # XXX: cannot always localize sub-exception, so why bother
            # placing it inside a localized one?
            return loc('Could not process request: [_1]', $e);
        }

        $self->rest->header(-status => HTTP_200_OK);
        return $rv;
    });
}

sub POST_to_membership { $_[0]->_admin_with_group_data_do_txn(sub {
    my ($self, $group, $data) = @_;

    for my $item (@$data) {
        my $name_or_id = $item->{user_id} || $item->{username}
            or die "Missing user_id/username";

        my $role = Socialtext::Role->new(name => $item->{role_name})
            or die "Role '$item->{role_name}' does not exist";

        my $user = Socialtext::User->Resolve($name_or_id);

        $group->has_user($user)
            or die "This group does not have $name_or_id as a user";

        $group->assign_role_to_user( user => $user, role => $role );
    }

    conflict errors => ["The group needs to include at least one admin."]
        unless $group->has_at_least_one_admin;

    return '';
}) }

sub POST_to_trash { $_[0]->_admin_with_group_data_do_txn(sub {
    my ($self, $group, $data) = @_;

    my $actor = $self->rest->user;

    for my $item (@$data) {
        if (my $name_or_id = $item->{user_id} || $item->{username}) {
            my $condemned = Socialtext::User->Resolve($name_or_id);
            $group->remove_user(user => $condemned, actor => $actor);
        }
        else {
            die "Bad data";
        }
    }

    conflict errors => ["The group needs to include at least one admin."]
        unless $group->has_at_least_one_admin;

    return '';
}) }

# Map to `PUT /data/groups/:group_id/users
sub PUT_to_users {
    my $self = shift;
    my $rest = shift;
    return $self->can_admin(sub {
        my $json = decode_json($rest->getContent());

        my $ctrl = $self->controller;
        $ctrl->scopes(['user']);
        $ctrl->actions([qw(add update remove)]);
        $ctrl->hooks()->{post_user_add} = sub {$self->user_invite(@_)}
            if (defined $json->{send_message} && $json->{send_message} == 1);

        $self->do_in_txn(sub {
            $ctrl->alter_members($json->{entry});
        });
    });
}

sub user_invite {
    my $self       = shift;
    my $user_role  = shift;

    Socialtext::JobCreator->insert(
        'Socialtext::Job::GroupInvite',
        {
            group_id  => $self->group->group_id,
            user_id   => $user_role->{user}->user_id,
            sender_id => $user_role->{actor}->user_id,
        },
    );
}

sub DELETE {
    my $self = shift;
    $self->can_admin(sub {
        $self->do_in_txn(sub {
            my $group = $self->group;
            $group->delete($self->rest->user);
        });
    });
}

sub can_admin {
    my $self = shift;
    my $cb   = shift;

    my $user  = $self->rest->user;
    my $group = $self->group;
    return $self->no_resource("Group with id " . $self->group_id )
        unless $group;

    my $admin = $group->user_can(user => $user, permission => ST_ADMIN_PERM);
    if ($admin || $user->is_business_admin || $user->is_technical_admin) {
        return $cb->();
    }

    return $self->not_authorized();
}

# XXX: This should live up higher in our stack.
sub do_in_txn {
    my $self  = shift;
    my $cb    = shift;
    my %addtl = @_; # user may pass in a CODEREF with index 'success'.

    eval { sql_txn { $cb->(@_) } };
    if (my $e = Exception::Class->caught('Socialtext::Exception')) {
        return $self->handle_exception($e);
    }
    if (my $e = $@) {
        warn $e;
        $self->rest->header(
            -status => HTTP_400_Bad_Request,
            -type   => 'text/plain',
        );
        return $e;
    }

    if (my $success = $addtl{success}) {
        return $success->();
    }

    $self->rest->header(-status => HTTP_204_No_Content);
    return '';
}

# XXX: This should live up higher in our stack, perhaps even the handler.
sub handle_exception {
    my $self = shift;
    my $e    = shift;

    if (!$e->isa('Socialtext::Exception')) {
        # XXX Server Error?
        return "WTF?";
    }

    my $status = {
        'Socialtext::Exception::Conflict'       => HTTP_409_Conflict,
        'Socialtext::Exception::DataValidation' => HTTP_409_Conflict,
    }->{ref($e)};

    $self->rest->header(-status => $status, -type   => 'text/plain');
    return join('\n', $e->messages);
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 NAME

Socialtext::Rest::Group - Group resource handler

=head1 SYNOPSIS

    GET /data/groups/:group_id
    PUT /data/groups/:group_id
    POST /data/groups/:group_id/trash
    POST /data/groups/:group_id/membership

=head1 DESCRIPTION

View and alter a group.

=cut
