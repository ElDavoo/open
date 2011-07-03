#!/usr/bin/env perl
# @COPYRIGHT@
use 5.12.0;
use FindBin;
use lib "$ENV{ST_CURRENT}/nlw/lib";
use lib "$FindBin::Bin/lib";
use Socialtext::PlackApp 'PerlHandler';
use Plack::Builder;

builder {
    enable XForwardedFor => (
        trust => [qw(127.0.0.1/8)],
    );

    enable SizeLimit => (
        max_unshared_size_in_kb => '368640',
    );

    # XXX "/nlw/ntlm" support

    mount '/nlw/control' => PerlHandler(
        'Socialtext::Handler::ControlPanel',
        'Socialtext::AccessHandler::IsBusinessAdmin',
    ),
    mount '/nlw' => PerlHandler('Socialtext::Handler::Authen'),
    mount '/' => PerlHandler('Socialtext::Handler::REST'),
};

