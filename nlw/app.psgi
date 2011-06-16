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
    my $out = $app->handler($r);

    given ($app->headerType) {
        when ('header') {
            return [200, [$app->header], [$out]];
        }
        when ('redirect') {
            my %h = $app->header();
            return [200, [%h], [Data::Dump::dump(\%h)]];
        }
        default {
            return [200, [], []];
        }
    }
};
