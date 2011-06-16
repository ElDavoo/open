#!/usr/bin/env perl
use 5.12.0;
use lib "$ENV{ST_CURRENT}/nlw/lib";
use lib "lib";
use Socialtext::Handler::REST;
use CGI::PSGI;
use Plack::Request;
use Data::Dump qw(dd);
use URI;

sub Plack::Request::header_in { scalar $_[0]->header($_[1]) }
sub Plack::Request::args { $ENV{QUERY_STRING} }
sub Plack::Request::cgi_env { %ENV }
sub Plack::Request::parsed_uri { URI->new($ENV{REQUEST_URI}) }
sub Plack::Request::log_error { dd @_ }
*URI::unparse = *URI::as_string;

my $app = sub {
    my $env = shift;
    delete $env->{"psgix.io"};

    my $r = Plack::Request->new($env);
    my $app = Socialtext::Handler::REST->new(
        request => $r,
        query => CGI::PSGI->new($env),
    );
    $ENV{REST_APP_RETURN_ONLY} = 1;

    local %ENV = %ENV;
    map { $ENV{$_} = $env->{$_} }
        grep { /^HTTP/ }
        keys %{$env};
    my ($h, $out) = $app->handler($r);

    my @headers = $h->header;
    my @actual_headers;
    my $status = 200;

    while (my $key = shift @headers) {
        my $val = shift @headers;
        $key =~ s/^-//;
        if ($key =~ /status/i) {
            $status = int($val) || 200;
            next;
        }
        push @actual_headers, $key, $val;
    }

    return [$status, \@actual_headers, [$out]];
};
