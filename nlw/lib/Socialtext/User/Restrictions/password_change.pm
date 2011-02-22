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

=head1 NAME

Socialtext::User::Restrictions::password_change - Password Change restriction

=head1 SYNOPSIS

  use Socialtext::User::Restrictions::password_change;

  # require that a User change their password
  my $restriction = Socialtext::User::Restrictions::password_change->CreateOrReplace( {
      user_id      => $user->user_id,
  } );

  # send the User the e-mail asking them to change their password
  $restriction->send_email;

  # clear the Restriction (after the User changes their password)
  $restriction->clear;

=head1 DESCRIPTION

This module implements a Restriction requiring the User to change their
password.

=head1 METHODS

=over

=item $self_or_class->restriction_type()

Returns the type of restriction this is.

=item $self->uri()

Returns the URI that the User should be directed to in order to change their
password.

=item $self->send_email()

Sends an e-mail message to the User informing them that they need to change
their password.

=back

=head1 COPYRIGHT

Copyright 2011 Socialtext, Inc., All Rights Reserved.

=cut
