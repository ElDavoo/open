package Socialtext::Rest::Group::Photo;
# @COPYRIGHT@
use strict;
use warnings;
use Socialtext::File;
use Socialtext::Group;
use Socialtext::Group::Photo;
use Socialtext::HTTP ':codes';

use base 'Socialtext::Rest';

sub group {
   return Socialtext::Group->GetGroup( group_id => shift->group_id );
}

sub _get_photo {
    my $self = shift;
    my $rest = shift;
    my $size = shift || 'large';

    my $user  = $rest->user;
    my $group = $self->group;

    my ($photo, $status);
    if ( $group ) {
        if ( $group->has_user($user) ) {
            $status = HTTP_200_OK;
            $photo  = $group->photo->$size;
        }
        else {
            $status = HTTP_401_Unauthorized;
            $photo  = Socialtext::Group::Photo->DefaultPhoto($size);
        }
    }
    else{
        $status = HTTP_404_Not_Found;
        $photo  = Socialtext::Group::Photo->DefaultPhoto($size);
    }

    $rest->header(
        -status        => $status,
        -pragma        => 'no-cache',
        -cache_control => 'no-cache, no-store',
        -type          => 'image/png',
    );
    return $photo;
}

sub GET_photo {
    my ($self, $rest) = @_;
    return $self->_get_photo($rest, 'large');
}

sub GET_small_photo {
    my ($self, $rest) = @_;
    return $self->_get_photo($rest, 'small');
}

1;

=head1 NAME

Socialtext::Rest::Group::Photo - Photo for a group

=head1 SYNOPSIS

    GET /data/groups/:group_id/photo
    GET /data/groups/:group_id/small_photo

=head1 DESCRIPTION

View the photo for a group.

=cut
