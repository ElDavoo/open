package Socialtext::Group::Photo;
# @COPYRIGHT@
use Moose;
use namespace::clean -except => 'meta';

use constant ROLES => ('Socialtext::Avatar', 'Socialtext::Avatar::Common');

# Required by Socialtext::Avatar:
use constant cache         => 'group-photo';
use constant table         => 'group_photo';
use constant id_column     => 'group_id';
use constant default_skin  => 'common';
use constant default_large => 'groupLarge.png';
use constant default_small => 'groupSmall.png';

sub Resize {
    my ($class, $size, $file) = @_;
    my $width = $size eq 'small' ? 27 : 62;
    Socialtext::Image::extract_rectangle(
        image_filename => $file,
        width => $width,
        height => $width,
    );
}

has 'group' => (
    is => 'ro', isa => 'Socialtext::Group',
    required => 1,
    handles => { group_id => 'group_id', 'id' => 'group_id' },
);

with(ROLES);
__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Socialtext::Group::Photo - the photo for a group.

=head1 SYNOPSIS

    my $photo = Socialtext::Group::Photo->new( group => $group );
    $photo->large;

=head1 DESCRIPTION

Storage for a group's photo.

=cut
