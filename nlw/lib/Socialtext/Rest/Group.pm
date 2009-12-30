package Socialtext::Rest::Group;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Rest::Entity';
use Socialtext::HTTP ':codes';
use Socialtext::JSON;
use Socialtext::Permission qw(ST_READ_PERM ST_ADMIN_PERM);
use Socialtext::Group;

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

sub PUT_json {
    my ($self, $rest) = @_;

    my $group = Socialtext::Group->GetGroup(group_id => $self->group_id);
    unless ($group) {
        $self->rest->header( -status => HTTP_404_Not_Found );
        return "Group not found";
    }

    my $can_admin = $group->user_can(
        user => $self->rest->user,
        permission => ST_ADMIN_PERM,
    );
    my $user = $self->rest->user;
    unless ($user->is_business_admin or $can_admin) {
        $rest->header( -status => HTTP_403_Forbidden );
        return 'You must be an admin to edit this group';
    }

    my $data = eval { decode_json( $rest->getContent ) };

    if (!$data or ref($data) ne 'HASH') {
        $rest->header( -status => HTTP_400_Bad_Request );
        return 'Content should be a JSON hash.';
    }
    unless ($data->{name}) {
        $rest->header( -status => HTTP_400_Bad_Request );
        return 'Name is required';
    }

    $group->update_store({
        driver_group_name => $data->{name},
        description => $data->{description} || "",
    });

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

1;

=head1 NAME

Socialtext::Rest::Group - Group resource handler

=head1 SYNOPSIS

    GET /data/groups/:group_id

=head1 DESCRIPTION

View the details of a group.

=cut
