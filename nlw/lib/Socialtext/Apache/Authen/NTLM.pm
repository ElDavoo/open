package Socialtext::Apache::Authen::NTLM;
# @COPYRIGHT@

use strict;
use warnings;
use Apache::Constants qw(HTTP_UNAUTHORIZED HTTP_FORBIDDEN HTTP_INTERNAL_SERVER_ERROR OK DECLINED);
use Socialtext::NTLM::Config;
use Socialtext::Log qw(st_log);
use Socialtext::l10n qw(loc);
use Socialtext::Session;

# mod_perl authen handler:
sub handler($$) {
    my ($class, $r) = @_;

    # turn HTTP KeepAlive requests *ON*
    st_log->debug( "turning HTTP Keep-Alives back on" );
    $r->subprocess_env(nokeepalive => undef);

    # call off to let the base class do its work
    #my $rc = $class->SUPER::handler($r);
    my $rc = call_ntlm_daemon($r);

    if ($rc == HTTP_UNAUTHORIZED) {
        _set_session_error( $r, { type => 'not_logged_in' } );
    }
    elsif ($rc == HTTP_FORBIDDEN) {
        _set_session_error( $r, { type => 'unauthorized_workspace' } );
    }
    elsif ($rc == HTTP_INTERNAL_SERVER_ERROR) {
        # Apache::AuthenNTLM throws a 500 when it can't speak to the PDC, and
        # this is the *ONLY* time it throws a 500
        $rc = HTTP_FORBIDDEN;
        st_log->error( "unable to reach the Windows NTLM DC to get nonce" );
        _set_session_error( $r, loc(
            "The Socialtext system cannot reach the Windows NTLM Domain Controller.  An Admin should check the Domain Controller and/or Socialtext configuration."
        ) );
    }
    st_log->debug( "NTLM authen handler rc: $rc" );

    return $rc;
}

use LWP::UserAgent;

sub call_ntlm_daemon {
    my $r = shift;
    my $ua = LWP::UserAgent->new;
    my $req = HTTP::Request->new('GET' => 'http://localhost:9090'.$r->uri.'?'.$r->args);

    unless ($r->header_in('Authorization')) {
        $r->err_headers_out->add('WWW-Authenticate' => 'NTLM');
        return HTTP_UNAUTHORIZED;
    }
    
    $req->header('X-Authorization' => $r->header_in('Authorization'));
    my $resp = $ua->request($req);

    if ($resp->is_success) {
        my $auth_header = $resp->header('X-WWW-Authenticate');
        if ($auth_header) {
            $r->err_headers_out->add('WWW-Authenticate' => $auth_header);
        }

        my $auth_user = $resp->header('X-User');
        if ($auth_user) {
            warn "GOT USER: $auth_user\n";
            $r->user($auth_user);
        }

        my $auth_status = $resp->header('X-Status');
        if ($auth_status eq 'OK') {
            $auth_status = OK;
        }
        elsif ($auth_status eq 'DECLINED') {
            $auth_status = DECLINED;
        }
        return $auth_status;
    }
    else {
        st_log->error("ntlm daemon returned ".$resp->status_line);
    }
    return HTTP_INTERNAL_SERVER_ERROR;
}

###############################################################################
# Throws away any error(s) in the current session and sets the error to the
# given error.
sub _set_session_error {
    my ($r, $error) = @_;
    my $session    = Socialtext::Session->new($r);
    my $throw_away = $session->errors();
    $session->add_error( $error );
}

1;

=head1 NAME

Socialtext::Apache::Authen::NTLM - Custom Apache NTLM Authentication handler

=head1 SYNOPSIS

  # In your Apache/Mod_perl config
  <Location /nlw/ntlm>
    SetHandler          perl-script
    PerlHandler         +Socialtext::Handler::Redirect
    PerlAuthenHandler   +Socialtext::Apache::Authen::NTLM
    Require             valid-user
  </Location>

=head1 DESCRIPTION

C<Socialtext::Apache::Authen::NTLM> is a custom Apache/Mod_perl authentication
handler, that uses NTLM for authentication and is derived from
C<Apache::AuthenNTLM>.  Please note that only NTLM v1 is implemented at this
time.

=head1 METHODS

=over

=item B<Socialtext::Apache::Authen::NTLM-E<gt>handler($request)>

Over-ridden C<handler()> method, which forcably turns B<on> HTTP Keep-Alive
requests before letting our base class to its work.

This re-enabling of Keep-Alive requests is required as they're auto-disabled
by C<Socialtext::InitHandler>.

=item B<$self-E<gt>get_config($request)>

Over-ridde C<get_config()> method, which reads in our configuration from
C<Socialtext::NTLM::Config>, instead of expecting it to be configured in the
Apache/Mod_perl configuration files.

You I<can> still use the Apache/Mod_perl configuration file to define NTLM
configuration, but this configuration will be supplemented/over-written by the
configuration read using C<Socialtext::NTLM::Config>.

=back

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc., All Rights Reserved.

=head1 SEE ALSO

L<Apache::AuthenNTLM>,
L<Socialtext::InitHandler>,
L<Socialtext::NTLM::Config>.

=cut
