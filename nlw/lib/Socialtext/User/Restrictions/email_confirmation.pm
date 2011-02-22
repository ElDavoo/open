package Socialtext::User::Restrictions::email_confirmation;

use Moose;
with 'Socialtext::User::Restrictions::base';

use Socialtext::AppConfig;
use Socialtext::EmailSender::Factory;
use Socialtext::l10n qw(system_locale loc);
use Socialtext::Pluggable::Adapter;
use Socialtext::TT2::Renderer;
use Socialtext::URI;

sub restriction_type { 'email_confirmation' };

# XXX - Yuck; this same URI is also used by "password_change"
sub uri {
    my $self = shift;
    return Socialtext::URI::uri(
        path  => '/nlw/submit/confirm_email',
        query => { hash => $self->token },
    );
}

sub send_email {
    my $self     = shift;
    my $user     = $self->user;
    my $uri      = $self->uri;
    my $renderer = Socialtext::TT2::Renderer->instance();
    my $workspace = $self->workspace;
    my %vars = (
        confirmation_uri => $uri,
        appconfig        => Socialtext::AppConfig->instance(),
        account_name     => $user->primary_account->name,
        target_workspace => $workspace
    );

    my $text_body = $renderer->render(
        template => 'email/email-address-confirmation.txt',
        vars     => \%vars,
    );

    my $html_body = $renderer->render(
        template => 'email/email-address-confirmation.html',
        vars     => \%vars,
    );

    my $locale       = system_locale();
    my $email_sender = Socialtext::EmailSender::Factory->create($locale);
    $email_sender->send(
        to        => $user->name_and_email(),
        subject   => $workspace
            ? loc('Welcome to the [_1] workspace - please confirm your email to join', $workspace->title)
            : loc('Welcome to the [_1] community - please confirm your email to join', $user->primary_account->name),
        text_body => $text_body,
        html_body => $html_body,
    );
}

sub send_completed_notifications {
    my $self = shift;
    $self->send_completed_email;
    $self->send_completed_signal unless $self->workspace_id;
}

sub send_completed_email {
    my $self     = shift;
    my $user     = $self->user;
    my $ws       = $self->workspace;
    my $renderer = Socialtext::TT2::Renderer->instance();
    my $app_name =
        Socialtext::AppConfig->is_appliance()
        ? loc('Socialtext Appliance')
        : loc('Socialtext');
    my @workspaces;
    my @groups;
    my $subject;

    if ($ws) {
        $subject = loc('You can now login to the [_1] workspace', $ws->title());
    }
    else {
        $subject = loc("You can now login to the [_1] application", $app_name);
        @groups     = $user->groups->all;
        @workspaces = $user->workspaces->all;
    }

    my %vars = (
        title => ($ws) ? $ws->title() : $app_name,
        uri   => ($ws) ? $ws->uri() : Socialtext::URI::uri(path => '/challenge'),
        workspaces       => \@workspaces,
        groups           => \@groups,
        target_workspace => $ws,
        user             => $user,
        app_name         => $app_name,
        appconfig        => Socialtext::AppConfig->instance(),
        support_address  => Socialtext::AppConfig->instance()->support_address,
    );

    my $text_body = $renderer->render(
        template => 'email/email-address-confirmation-completed.txt',
        vars     => \%vars,
    );

    my $html_body = $renderer->render(
        template => 'email/email-address-confirmation-completed.html',
        vars     => \%vars,
    );

    my $locale       = system_locale();
    my $email_sender = Socialtext::EmailSender::Factory->create($locale);
    $email_sender->send(
        to        => $user->name_and_email(),
        subject   => $subject,
        text_body => $text_body,
        html_body => $html_body,
    );
}

sub send_completed_signal {
    my $self = shift;

    my $signals = Socialtext::Pluggable::Adapter->plugin_class('signals');
    return unless $signals;

    my $user = $self->user;
    my $wafl = '{user: ' . $user->user_id . '}';
    my $body = loc(
        '[_1] just joined the [_2] group. Hi everybody!',
        $wafl, $user->primary_account->name,
    );
    eval {
        $signals->Send( {
            user        => $user,
            account_ids => [ $user->primary_account_id ],
            body        => $body,
        } );
    };
    warn $@ if $@;
}

__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

Socialtext::User::Restrictions::email_confirmation - Email Confirmation restriction

=head1 SYNOPSIS

  use Socialtext::User::Restrictions::email_confirmation;

  # require that a User confirm their e-mail address
  my $restriction = Socialtext::User::Restrictions::email_confirmation->CreateOrReplace( {
      user_id      => $user->user_id,
      workspace_id => $workspace->workspace_id,
  } );

  # send the User the e-mail asking them to confirm their e-mail address
  $restriction->send_email;

  # let the User know that they've completed the confirmation
  $restriction->send_completed_notifications;

  # clear the Restriction (after the User completed their confirmation)
  $restriction->clear;

=head1 DESCRIPTION

This module implements a Restriction requiring the User to confirm their
e-mail address.

=head1 METHODS

=over

=item $self_or_class->restriction_type()

Returns the type of restriction this is.

=item $self->uri()

Returns the URI that the User should be directed to in order to confirm their
e-mail address.

=item $self->send_email()

Sends an e-mail message to the User informing them that they need to confirm
their e-mail address before they have access to their account.

=item $self->send_completed_notifications()

Sends out all of the notifications necessary, once the User has confirmed
their e-mail address.

=item $self->send_completed_email()

Sends an e-mail message to the User, letting them know that they've completed
the process of confirming their e-mail address.

=item $self->send_completed_signal()

Sends a Signal, indicating to other Users that this individual just completed
the process of confirming their e-mail address, welcoming him/her to the
system.

=back

=head1 COPYRIGHT

Copyright 2011 Socialtext, Inc., All Rights Reserved.

=cut
