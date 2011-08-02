package Socialtext::Rest::SettingsTheme;
use Moose;
use Socialtext::Prefs::System;
use Socialtext::JSON qw(encode_json decode_json);

extends 'Socialtext::Rest::Entity';

has 'prefs' => (is => 'ro', isa => 'Socialtext::Prefs', lazy_build => 1);
sub _build_prefs {
    my $self = shift;
    return Socialtext::Prefs::System->new();
}

sub GET_theme {
    my $self = shift;
    my $rest = shift;

    return $self->not_authorized()
        unless $self->rest->user->is_technical_admin();

    my $prefs = $self->prefs->all_prefs;

    $rest->header(-type=>'application/json');
    return encode_json($prefs->{theme});
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
