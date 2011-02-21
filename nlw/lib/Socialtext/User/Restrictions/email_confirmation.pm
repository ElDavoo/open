package Socialtext::User::Restrictions::email_confirmation;

use Moose;
with 'Socialtext::User::Restrictions::base';

use Socialtext::AppConfig;
use Socialtext::EmailSender::Factory;
use Socialtext::l10n qw(system_locale);
use Socialtext::TT2::Renderer;

sub restriction_type { 'email_confirmation' };

sub send_email {
    my $self = shift;
    my $user = $self->user;

    my $renderer = Socialtext::TT2::Renderer->instance();

    my $uri = $self->uri;

    my $target_workspace;

    if (my $wsid = $self->workspace_id) {
        require Socialtext::Workspace;      # lazy-load, to reduce startup impact
        $target_workspace = new Socialtext::Workspace(workspace_id => $wsid);
    }
    my %vars = (
        confirmation_uri => $uri,
        appconfig        => Socialtext::AppConfig->instance(),
        account_name     => $user->primary_account->name,
        target_workspace => $target_workspace
    );

    my $text_body = $renderer->render(
        template => 'email/email-address-confirmation.txt',
        vars     => \%vars,
    );

    my $html_body = $renderer->render(
        template => 'email/email-address-confirmation.html',
        vars     => \%vars,
    );

    # XXX if we add locale per workspace, we have to get the locale from hub.
    my $locale = system_locale();
    my $email_sender = Socialtext::EmailSender::Factory->create($locale);
    $email_sender->send(
        to        => $user->name_and_email(),
        subject   => $target_workspace ? 
            loc('Welcome to the [_1] workspace - please confirm your email to join', $target_workspace->title)
            :
            loc('Welcome to the [_1] community - please confirm your email to join', $user->primary_account->name),
        text_body => $text_body,
        html_body => $html_body,
    );
}

__PACKAGE__->meta->make_immutable;

1;
