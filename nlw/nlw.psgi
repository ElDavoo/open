#!/usr/bin/env perl
use 5.12.0;
use FindBin;
use lib "$ENV{ST_CURRENT}/nlw/lib";
use lib "$FindBin::Bin/lib";
use Socialtext::PlackApp 'PerlHandler';
use Plack::Builder;

builder {
    enable 'Plack::Middleware::XForwardedFor' => (
        trust => [qw(127.0.0.1/8)],
    );

    enable "Plack::Middleware::SizeLimit" => (
        max_unshared_size_in_kb => '368640'
    ) unless $^O eq 'darwin';

    # XXX "/nlw/ntlm" support

    mount '/nlw/control' => PerlHandler(
        'Socialtext::Handler::ControlPanel',
        'Socialtext::AccessHandler::IsBusinessAdmin',
    ),
    mount '/nlw' => PerlHandler('Socialtext::Handler::Authen'),
    mount '/' => PerlHandler('Socialtext::Handler::REST'),
};

