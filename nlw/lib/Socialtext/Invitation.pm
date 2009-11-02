package Socialtext::Invitation;
# @COPYRIGHT@
use Moose;
use Socialtext::AppConfig;
use Socialtext::TT2::Renderer;
use Socialtext::URI;
use Socialtext::JobCreator;
use Socialtext::Job::AccountInvite;
use Socialtext::User;
use Socialtext::l10n qw(system_locale loc);
use Socialtext::EmailSender::Factory;
use namespace::clean -except => 'meta';

has 'from_user' => (
    is       => 'ro', isa => 'Socialtext::User',
    required => 1,
);

has 'viewer'  => (is => 'ro', isa => 'Socialtext::User',);
has 'extra_text' => (is => 'ro', isa => 'Maybe[Str]',);
has 'extra_args' => (is => 'ro', isa => 'Hash', lazy_build => 1);

sub invite_notify {
    my $self       = shift;
    my $user       = shift;
    my $template_dir = 'st';

    my $app_name = Socialtext::AppConfig->is_appliance()
        ? 'Socialtext Appliance'
        : 'Socialtext';

    my %vars = (
        username              => $user->username,
        requires_confirmation => $user->requires_confirmation,
        confirmation_uri      => $user->confirmation_uri || '',
        host                  => Socialtext::AppConfig->web_hostname(),
        inviting_user         => $self->{from_user}->best_full_name,
        app_name              => $app_name,
        forgot_password_uri   =>
            Socialtext::URI::uri(path => '/nlw/forgot_password.html'),
        appconfig => Socialtext::AppConfig->instance(),
        $self->_template_args,
    );

    my $extra_text = $self->extra_text;
    my $type = $self->_template_type;
    my $renderer = Socialtext::TT2::Renderer->instance();
    my $text_body = $renderer->render(
        template => "email/$template_dir/$type-invitation.txt",
        vars     => {
            %vars,
            extra_text => $extra_text,
        }
    );

    my $html_body = $renderer->render(
        template => "email/$type-invitation.html",
        vars     => {
            %vars,
            invitation_body =>
                "email/$template_dir/$type-invitation-body.html",
            extra_text => $self->{viewer}
                ? $self->{viewer}->process($extra_text || '')
                : $extra_text,
        }
    );

    my $locale = system_locale();
    my $email_sender = Socialtext::EmailSender::Factory->create($locale);
    my $subject = $self->_subject;
    $email_sender->send(
        from      => $self->from_user->name_and_email,
        to        => $user->email_address,
        subject   => $subject,
        text_body => $text_body,
        html_body => $html_body,
    );

    $self->_log_action("INVITE_USER_ACCOUNT", $user->email_address);
}

sub _log_action {
    my $self = shift;
    my $action = shift;
    my $extra  = shift;
    my $name = $self->_name;
    my $page_name = '';
    my $user_name = $self->{from_user}->user_id;
    my $log_msg = "$action : $name : $page_name : $user_name";
    if ($extra) {
        $log_msg .= " : $extra";
    }
    Socialtext::Log->new()->info("$log_msg");
}

__PACKAGE__->meta->make_immutable;
1;

