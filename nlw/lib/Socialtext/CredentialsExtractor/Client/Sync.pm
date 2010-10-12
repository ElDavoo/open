package Socialtext::CredentialsExtractor::Client::Sync;
# @COPYRIGHT@

use Moose;
use AnyEvent;
use namespace::clean -except => 'meta';
BEGIN { extends 'Socialtext::CredentialsExtractor::Client::Async' };

around '_send_request' => sub {
    my $orig = shift;
    my $cv   = AE::cv;
    $orig->(@_, sub { $cv->send(shift) });

    # under Coro: schedule other coros (yield), one of those coros runs the
    #             event loop.
    # without Coro: enter the event loop and wait; effectively blocks
    return $cv->recv;
};

override 'ExtractCredentials' => sub {
    my $self = shift;
    my $hdrs = shift;
    my $creds;
    super($hdrs, sub { $creds = shift } );
    return $creds;
};

__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

Socialtext::CredentialsExtractor::Client::Sync - Synchronous Creds Extraction

=head1 SYNOPSIS

  use Socialtext::CredentialsExtractor::Client::Sync;

  my $client = Socialtext::CredentialsExtractor::Client::Sync->new();
  my $creds  = $client->ExtractCredentials(\%ENV);
  if ($creds->{valid}) {
      # Valid User found (which *COULD* be the Guest User)
  }

=head1 DESCRIPTION

This module implements a synchronous/blocking Credentials Extraction client.

=cut
