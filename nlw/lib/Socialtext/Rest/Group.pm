package Socialtext::Rest::Group;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Rest::Entity';
use Socialtext::HTTP ':codes';
use Socialtext::JSON;
use Socialtext::l10n qw(loc);
use Socialtext::Permission qw(ST_READ_PERM ST_ADMIN_PERM
                              ST_ADMIN_WORKSPACE_PERM);
use Socialtext::Group;
use Socialtext::SQL ':txn';

sub permission      { +{} }
sub allowed_methods {'GET, PUT'}
sub entity_name     { "Group" }

sub get_resource {
    my( $self, $rest ) = @_;

    my $group = Socialtext::Group->GetGroup(group_id => $self->group_id);
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

sub PUT_json {
    my ($self, $rest) = @_;

    my $error = $self->_has_request_error(
        permissions => [ST_ADMIN_PERM],
    );
    if ($error) {
        $rest->header(-status => $error->{status});
        return $error->{message};
    }

    my $group = Socialtext::Group->GetGroup(group_id => $self->group_id);
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

    return undef;
}

sub _has_request_error {
    my $self = shift;
    my %p    = (
        permissions => undef,
        @_
    );
    my $rest = $self->rest;
    my $user = $rest->user;

    my $group = Socialtext::Group->GetGroup(group_id => $self->group_id);
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

sub POST_to_trash {
    my $self  = shift;
    my $rest  = shift;
    my $actor = $rest->user;

    my $error = $self->_has_request_error(
        permissions => [ST_ADMIN_PERM]
    );
    if ($error) {
        $rest->header(-status => $error->{status});
        return $error->{message};
    }

    my $group = Socialtext::Group->GetGroup(group_id => $self->group_id);
    my $data  = eval{ decode_json($rest->getContent) };
    $data = (ref($data) eq 'HASH') ? [$data] : $data;

    unless ($data) {
        $rest->header(-status => HTTP_400_Bad_Request);
        return loc('Malformed JSON passed to resource');
    }

    sql_begin_work();
    eval {
        for my $item (@$data) {
            $self->_remove_item($item, $group);
        }
    };
    if ($@) {
        sql_rollback();
        $rest->header(-status => HTTP_400_Bad_Request);
        return loc('Could not process request');
    }

    sql_commit();
    $rest->header(-status => HTTP_200_OK);
    return '';
}

sub _remove_item {
    my $self  = shift;
    my $item  = shift;
    my $group = shift;

    my $actor = $self->rest->user;
    if (my $name_or_id = $item->{user_id} || $item->{username}) {
        my $condemned = Socialtext::User->Resolve($name_or_id);
        $group->remove_user(user => $condemned, actor => $actor);
    }
    elsif (my $ws_id = $item->{workspace_id}) {
        my $ws = Socialtext::Workspace->new(workspace_id => $ws_id)
            or die 'no workspace';

        my $perm = $ws->permissions->user_can(
            user       => $actor,
            permission => ST_ADMIN_WORKSPACE_PERM,
        );
        die "don't have permission" unless $perm || $actor->is_business_admin;

        $ws->remove_group(group => $group, actor => $actor);
    }
    else {
        die "Bad data";
    }
}
1;

=head1 NAME

Socialtext::Rest::Group - Group resource handler

=head1 SYNOPSIS

    GET /data/groups/:group_id

=head1 DESCRIPTION

View the details of a group.

=cut
