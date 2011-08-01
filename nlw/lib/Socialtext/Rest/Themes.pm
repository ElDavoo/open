package Socialtext::Rest::Themes;
use Moose;
use Socialtext::Theme;
use Socialtext::JSON qw(encode_json);
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest::Collection';

sub GET_themes {
    my $self = shift;
    my $rest = shift;

    return $self->not_authorized() if $self->rest->user->is_guest;

    my $hashes = [ map { $_->as_hash } @{Socialtext::Theme->All()} ];

    return encode_json($hashes);
}

sub GET_theme {
    my $self = shift;
    my $rest = shift;

    return $self->not_authorized() if $self->rest->user->is_guest;
    my $theme = $self->_get_theme();

    return $theme
        ? encode_json($theme->as_hash)
        : $self->no_resource('theme');
}

sub _get_theme {
    my $self = shift;

    my $theme;
    $theme = Socialtext::Theme->Load(theme_id => $self->theme)
        if $self->theme =~ /^\d+$/;

    $theme ||= Socialtext::Theme->Load(name => $self->theme);

    return $theme;
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
