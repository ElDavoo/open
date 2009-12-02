package Socialtext::Rest::Group::Photo;
# @COPYRIGHT@
use strict;
use warnings;
use Socialtext::File;
use Socialtext::Group;

use base 'Socialtext::Rest';

sub _get_photo {
    my $self = shift;
    my $rest = shift;
    my $size = shift || 'large';

    my $group = Socialtext::Group->GetGroup(group_id => $self->group_id);

    # send the default photo back, but such that it'll get re-requested again
    # once per page.
    my %headers = $rest->header;
    $rest->header(
        -status        => $headers{-status},
        -pragma        => 'no-cache',
        -cache_control => 'no-cache, no-store',
        -type          => 'image/png',
    );
    return $group->photo->$size;
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
