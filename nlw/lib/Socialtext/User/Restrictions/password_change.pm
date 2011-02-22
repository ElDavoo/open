package Socialtext::User::Restrictions::password_change;

use Moose;
with 'Socialtext::User::Restrictions::base';

use Socialtext::AppConfig;
use Socialtext::EmailSender::Factory;
use Socialtext::l10n qw(system_locale loc);
use Socialtext::TT2::Renderer;

sub restriction_type { 'password_change' };

# XXX - Yuck; this uses the same URI as the "email_confirmation"
sub uri {
    my $self = shift;
    return Socialtext::URI::uri(
        path  => '/nlw/submit/confirm_email',
        query => { hash => $self->token },
    );
}

sub send_email {
    my $self = shift;
    my $user = $self->user;

    my $renderer = Socialtext::TT2::Renderer->instance();

    my $uri = $self->uri;

    my %vars = (
        appconfig        => Socialtext::AppConfig->instance(),
        confirmation_uri => $uri,
    );

    my $text_body = $renderer->render(
        template => 'email/password-change.txt',
        vars     => \%vars,
    );

    my $html_body = $renderer->render(
        template => 'email/password-change.html',
        vars     => \%vars,
    );
    my $locale = system_locale();
    my $email_sender = Socialtext::EmailSender::Factory->create($locale);
    $email_sender->send(
        to        => $user->name_and_email(),
        subject   => loc('Please follow these instructions to change your Socialtext password'),
        text_body => $text_body,
        html_body => $html_body,
    );
}

__PACKAGE__->meta->make_immutable;

1;
