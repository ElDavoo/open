#!/usr/bin/env perl
use 5.12.0;
use lib "$ENV{ST_CURRENT}/nlw/lib";
use lib "lib";
use CGI::PSGI;
use Plack::Request;
use Data::Dump qw(dd);
use URI;
use Test::MockObject;
use Encode ();
use Plack::Builder;
use Log::Dispatch;
use Module::Load;
use Plack::Response;
use HTTP::Status ();

{
    package _Connection;
    use parent 'Class::Accessor';
    __PACKAGE__->mk_accessors(qw(user));
}


sub Apache::Cookie::fetch { shift; @_ ? $::Request->cookies->{$_[0]} : $::Request->cookies }
sub Apache::request { $::Request }
sub Apache::Request::new { $::Request }
sub Apache::Request::instance { $::Request }

for my $method (@{$HTTP::Status::EXPORT_TAGS{constants}}) {
    no strict 'refs';
    (my $code = $method) =~ s/^HTTP_//;
    my $value = &{"HTTP::Status::$method"}();
    *{"Apache::Constants::$code"} = sub { $value };
    if ($method eq 'HTTP_FOUND') {
        *{"Apache::Constants::REDIRECT"} = sub { $value };
    }
}

sub Plack::Response::err_headers_out { $_[0] }
sub Plack::Response::add { (shift)->header(\@_) }

{
    package _Request;
    use parent 'Plack::Request';
    no warnings 'redefine';
    sub content_type {
        my $self = shift;
        if (@_) {
            $::PlackResponse->content_type(@_);
        }
        else {
            $self->SUPER::content_type();
        }
    }
    sub uri {
        (caller =~ /^Socialtext::/) ? $_[0]->SUPER::uri->path : $_[0]->SUPER::uri
    }
    sub print { shift; $::PlackResponse->body(@_) }
    sub header_out { shift; $::PlackResponse->header(@_) }
    sub send_http_header { undef }
    sub prev { undef }
    sub header_in { scalar $_[0]->header($_[1]) }
    sub args { $ENV{QUERY_STRING} }
    sub cgi_env { %ENV }
    sub parsed_uri { URI->new($ENV{REQUEST_URI}) }
    sub log_error { warn @_ }
    sub connection {
        $_[0]{_connection} //= _Connection->new
    }
}
*URI::unparse = *URI::as_string;

sub PerlHandler { load(my $handler_class = shift); return sub {
    my $env = shift;
    delete $env->{"psgix.io"};

    local $::Request = _Request->new($env);
    my $r = $::Request;

    my $app = $handler_class->can('new') ? $handler_class->new(
        request => $r,
        query => CGI::PSGI->new($env),
    ) : $handler_class;
    $ENV{REST_APP_RETURN_ONLY} = 1;

    local %ENV = %ENV;
    map { $ENV{$_} = $env->{$_} }
        grep { /^HTTP/ }
        keys %{$env};

    local $::PlackResponse = Plack::Response->new(200);
    my $res = $::PlackResponse;
    my ($h, $out) = $app->handler($r);

    if (!defined $out) {
        # A simple status is returned
        $res->status($h || 200);
        return $res->finalize;
    }

    my @headers = $h->header;
    $res->content_type('text/html; charset=UTF-8');

    while (my $key = shift @headers) {
        my $val = shift @headers;
        $key =~ s/^-//;
        if ($key =~ /status/i) {
            $res->status(int($val) || 200);
            next;
        }
        $res->headers([$key => $val]);
    }

    Encode::_utf8_off($out);
    $res->body($out);
    return $res->finalize;
} };

my $logger = Log::Dispatch->new(
    outputs => [
        [ 'File', min_level => 'debug', filename => "$ENV{HOME}/.nlw/log/nlw-psgi/access.log" ]
    ],
);

builder {
    enable 'Plack::Middleware::XForwardedFor' => (
        trust => [qw(127.0.0.1/8)],
    );

    enable "Plack::Middleware::AccessLog" => (
        format => "combined",
        logger => sub { $logger->debug(@_) },
    );
    mount '/nlw/control' => PerlHandler('Socialtext::Handler::ControlPanel'),
    mount '/nlw' => PerlHandler('Socialtext::Handler::Authen'),
    mount '/' => PerlHandler('Socialtext::Handler::REST'),
};
