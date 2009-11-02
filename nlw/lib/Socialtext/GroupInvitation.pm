package Socialtext::GroupInvitation;
# @COPYRIGHT@
use Moose;
use Socialtext::URI;
use Socialtext::l10n qw(system_locale loc);
use namespace::clean -except => 'meta';

extends 'Socialtext::Invitation';

our $VERSION = '0.01';

has 'group' => (
    is       => 'ro', isa => 'Socialtext::Group',
    required => 1,
);

sub _name {
    my $self = shift;
    return $self->group->driver_group_name;
}

sub _subject {
    my $self = shift;
    my $name = $self->group->driver_group_name;
    loc("I'm inviting you into the [_1] group", $name);
}

sub _template_type { 'group' }

sub _template_args {
    my $self = shift;
    return (
        group_name => $self->group->driver_group_name,
        group_uri  => Socialtext::URI::uri(path => '/'),
    );
}

__PACKAGE__->meta->make_immutable;
1;
