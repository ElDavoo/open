package Socialtext::Pluggable::Plugin::Locales;
# @COPYRIGHT@
use warnings;
use strict;
use Socialtext::l10n qw/loc system_locale/;
use Socialtext::Locales qw/available_locales/;
use base 'Socialtext::Pluggable::Plugin';

use constant scope => 'always';
use constant hidden => 1; # hidden to admins
use constant read_only => 0; # cannot be disabled/enabled in the control panel

sub register {
    my $self = shift;

    $self->add_hook("action.language_settings"   => \&language_settings);
}

sub language_settings {
    my $self = shift;
    my %cgi_vars = $self->cgi_vars;

    $self->challenge(type => 'settings_requires_account')
        unless ($self->logged_in);

    my $languages = available_locales();
    my $choices = [ map { +{
        value => $_,
        label => $languages->{$_}
    }} sort keys %$languages ];

    unshift @$choices, {
        value => "",
        label => loc("System Default: [_1]", $languages->{system_locale()}),
    };

    my $settings_section = $self->template_render(
        'element/settings/language_settings_section',
        form_action    => 'language_settings',
        locales        => $choices,
    );

    return $self->template_render('view/settings',
        settings_table_id => 'settings-table',
        settings_section  => $settings_section,
        display_title     => loc('Language Settings'),
    );
}

1;
__END__

=head1 NAME

Socialtext::Pluggable::Plugin::Locale

=head1 SYNOPSIS

Per-user localization preferences.

=head1 DESCRIPTION

=cut
