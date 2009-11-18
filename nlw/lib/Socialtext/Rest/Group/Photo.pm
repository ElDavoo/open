package Socialtext::Rest::Group::Photo;
# @COPYRIGHT@
use strict;
use warnings;
use Socialtext::File;
use Socialtext::Group::Photo;

use base 'Socialtext::Rest';

sub _get_photo {
    my $self = shift;
    my $rest = shift;
    my $size = shift || 'large';

    # slurp in the default avatar image
    my $photo = Socialtext::Group::Photo->new(
        group_id => $self->group_id,
        size => $size,
    );

    # send the default photo back, but such that it'll get re-requested again
    # once per page.
    my %headers = $rest->header;
    $rest->header(
        -status        => $headers{-status},
        -pragma        => 'no-cache',
        -cache_control => 'no-cache, no-store',
        -type          => 'image/png',
    );
    return $photo->blob;
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
