package Socialtext::Client::Wiki;
# @COPYRIGHT@
use 5.12.0;
use warnings;
use parent 'Exporter';
use LWP::UserAgent;
use HTTP::Request::Common;
use Socialtext::HTTP::Ports;

our @EXPORT = qw( wiki2html html2wiki );

sub wiki2html {
    unshift @_, 'wiki';
    goto &_request;
}

sub html2wiki {
    unshift @_, 'html';
    goto &_request;
}

sub _request {
    state $ua //= LWP::UserAgent->new;
    state $wikid_url //= "http://127.0.0.1:".Socialtext::HTTP::Ports->wikid_port;
    my $request = POST $wikid_url, \@_;
    my $response = $ua->simple_request($request);
    return $response->decoded_content;
}

1;
