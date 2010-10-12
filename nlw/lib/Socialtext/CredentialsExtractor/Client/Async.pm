package Socialtext::CredentialsExtractor::Client::Async;
# @COPYRIGHT@

use Moose;
use AnyEvent::HTTP qw(http_request);
use Try::Tiny;
use Socialtext::JSON qw(encode_json decode_json);
use Socialtext::HTTP::Ports;
use Socialtext::CredentialsExtractor;
use namespace::clean -except => 'meta';

has 'userd_host' => (
    is => 'ro', isa => 'Str', default => 'localhost',
);
has 'userd_port' => (
    is => 'ro', isa => 'Int', default => Socialtext::HTTP::Ports->userd_port,
);
has 'userd_path' => (
    is => 'ro', isa => 'Str', default => '/stuserd',
);
has 'userd_uri' => (
    is => 'ro', isa => 'Str', lazy_build => '1',
);
sub _build_userd_uri {
    my $self = shift;
    my $host = $self->userd_host;
    my $port = $self->userd_port;
    my $path = $self->userd_path;
    return "http://$host\:$port$path";
}

sub extract_desired_headers {
    my $self = shift;
    my $hdrs = shift;
    my @header_list  = Socialtext::CredentialsExtractor->HeadersNeeded();
    my %hdrs_to_send =
        map  { $_->[0] => $_->[1] }
        grep { defined $_->[1] }
        map  { [$_ => $hdrs->{$_} || $hdrs->{"HTTP_$_"}] }
        @header_list;
    return \%hdrs_to_send;
}

sub ExtractCredentials {
    my $self = shift;
    my $hdrs = shift;
    my $cb   = shift;

    # minimal headers needing to be send to st-userd
    my $hdrs_to_send = $self->extract_desired_headers($hdrs);

    # XXX: check client-side cache

    # send request off to st-userd
    try {
        $self->_send_request($hdrs_to_send, $cb);
    }
    catch {
        # XXX handle error from sending/decoding
        my $err = $_;
        warn "ERROR[$err]\n"; # XXX - handle better
    };
}

sub _send_request {
    my ($self, $hdrs, $cb) = @_;
    my $url  = $self->userd_uri;
    my $body = encode_json($hdrs);

    http_request POST => $url,
        headers => {
            'Referer'    => '',
            'User-Agent' => __PACKAGE__,
        },
        body    => $body,
        timeout => 30,
        sub {
            my ($body, $hdrs) = @_;
            if ($hdrs->{Status} >= 500) {
                die 'ExtractCreds: '.$hdrs->{Reason} . "\n";
            }
            my $creds = decode_json($body);

            # XXX cache results

            $cb->($creds);
        };
    return; # force http_request void context
}

__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

Socialtext::CredentialsExtractor::Client::Async - Asynchronous Creds Extraction

=head1 SYNOPSIS

  use Socialtext::CredentialsExtractor::Client::Async;

  my $client = Socialtext::CredentialsExtractor::Client::Async->new();
  $client->ExtractCredentials($env, sub {
      my $creds = shift;
      if ($creds->{valid}) {
          # Valid User found (which *COULD* be the Guest User)
      }
  } );

=head1 DESCRIPTION

This module implements an asynchronous, callback-style Credentials Extraction
client.

=cut
