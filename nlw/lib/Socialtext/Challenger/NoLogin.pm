package Socialtext::Challenger::NoLogin;
# @COPYRIGHT@
use strict;
use warnings;
use Socialtext::WebApp;

use base 'Socialtext::Challenger::Base';

sub challenge {
    my $class = shift;
    my %p = @_;

    my $request  = delete $p{request};
    my $redirect = delete $p{redirect};

    my $app = Socialtext::WebApp->NewForNLW;
    $request  ||= $app->apache_req;
    $redirect ||= $request->parsed_uri->unparse;

    my $to = $class->is_mobile($redirect) ? '/m/nologin' : '/nlw/nologin.html';
    $app->redirect($to);
}

1;
