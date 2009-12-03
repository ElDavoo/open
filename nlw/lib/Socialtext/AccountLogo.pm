package Socialtext::AccountLogo;
# @COPYRIGHT@
use Moose;
use File::Spec;
use File::Temp qw/tempfile/;
use Socialtext::File;
use Socialtext::Skin;
use Socialtext::Paths;
use Socialtext::Image;
use namespace::clean -except => 'meta';

use constant ROLES => ('Socialtext::Avatar');

# Required by Socialtext::Avatar:
use constant cache => 'account_logo';
use constant table => 'account_logo';
use constant id_column => 'account_id';
use constant default_logo => 'logo.png';
use constant default_skin => 'common';

sub Resize {
    my ($class, $size, $file) = @_;
    Socialtext::Image::resize(
        filename => $file,
        max_width => 201,
        max_height => 36,
    );
}

has 'account' => (
    is => 'ro', isa => 'Socialtext::Account',
    required => 1,
    weak_ref => 1,
    handles => [qw(account_id)],
);

has 'id' => (
    is => 'ro', isa => 'Int',
    lazy_build => 1,
);
sub _build_id { $_[0]->account_id }

has 'synonyms' => (
    is => 'ro', isa => 'ArrayRef',
    auto_deref => 1,
    lazy_build => 1,
);

sub _build_synonyms {
    my $self = shift;
    my $default = Socialtext::Account->Default();
    return $default->account_id == $self->account_id ? [0] : [];
}

has 'versions' => (
    is => 'ro', isa => 'ArrayRef',
    default => sub {['logo']},
    auto_deref => 1,
);

has 'logo' => (
    is => 'rw', isa => 'ScalarRef',
    lazy_build => 1,
);
sub _build_logo { $_[0]->load(logo => 'logo') }

with(ROLES);
__PACKAGE__->meta->make_immutable;
