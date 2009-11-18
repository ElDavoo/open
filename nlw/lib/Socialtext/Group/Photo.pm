package Socialtext::Group::Photo;
# @COPYRIGHT@
use Moose;
use namespace::clean -except => 'meta';

sub Default {
    my $class = shift;
    my $obj = $class->new(@_);
}

has 'size' => (
    is => 'rw', isa => 'Str',
    default => 'large',
);

has 'default_path' => (
    is => 'ro', isa => 'Str',
    lazy_build => 1,
);

sub _build_default_path {
    my $self = shift;
    my $img = ($self->size eq 'large') ? 'bigAvatar.png' : 'avatar.png';

    # get the path to the image, on *disk*
    my $skin = Socialtext::Skin->new( name => 'common' );
    my $loc = File::Spec->catfile(
        $skin->skin_path,
        "images/$img",
    );
    die "image '$loc' not found!" unless (-e $loc);

    return $loc;
}

has 'blob' => (
    is => 'rw',
    lazy_build => 1,
);

sub _build_blob {
    my $self = shift;
    return scalar Socialtext::File::get_contents_binary($self->default_path);
}

__PACKAGE__->meta->make_immutable;
1;
