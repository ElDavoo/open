package Socialtext::Challenger::SSLCertificate;
# @COPYRIGHT@

use strict;
use warnings;
use base qw(Socialtext::Challenger::Base);
use Socialtext::Apache::User;
use Socialtext::Log qw(st_log);
use Socialtext::User;
use Socialtext::WebApp;

sub challenge {
    my $class    = shift;
    my %p        = @_;
    my $hub      = $p{hub};
    my $request  = $p{request};
    my $redirect = $p{redirect};

    # make sure we've got a request
    my $app = Socialtext::WebApp->NewForNLW;
    unless ($request) {
        $request = $app->apache_req;
    }


    # if we have a Hub *AND* a User, we're Authentiated but not Authorized;
    # show the User a page letting them know that they don't have permission.
    if ($hub and not $hub->current_user->is_guest) {
        st_log->debug( 'ST::Challenger::SSLCertificate: unauthorized access, showing error page to user' );
        return $app->_handle_error(
            error => {
                type => 'unauthorized_workspace',
            },
            path    => '/nlw/error.html',
        );
    }

    # figure out where the User is supposed to be redirected to after the
    # challenge is successful.
    $redirect ||= $class->get_redirect_uri($request);
    $redirect = $class->clean_redirect_uri($redirect);

    # extract the username from the SSL Certificate Subject
    my $subject  = $request->header_in('X-SSL-Client-Subject-DN');
    my $username = $class->_extract_cn($subject);
    my $user     = eval { Socialtext::User->new(username => $username) };

    # if we don't know who this User is, don't let them in.
    unless ($user) {
        my $err = loc("Have Client-Side SSL cert, but for unknown user '[_1]'.", $username);
        st_log->warning("ST::Challenger::SSLCertificate: $err");
        $app->session->add_error($err);
        return $app->_handle_error(
            path => '/nlw/error.html',
        );
    }

    # figure out where the User wanted to be in the first place, and redirect
    # them off over there.
    st_log->info("LOGIN: " . $user->email_address . " destination $redirect");
    Socialtext::Apache::User::set_login_cookie($request, $user->user_id, '');
    $user->record_login;
    return $app->redirect($redirect);
}

# Possible formats:
#   /C=US/ST=CA/L=Palo Alto/O=Socialtext/CN=devnull1@socialtext.com/...
#   /C=US/ST=CA/L=Palo Alto/O=Socialtext/CN=devnull1@socialtext.com
#   C=US, ST=CA, L=Palo Alto, O=Socialtext, CN=devnull1@socialtext.com, ...
#   C=US, ST=CA, L=Palo Alto, O=Socialtext, CN=devnull1@socialtext.com
sub _extract_cn {
    my $class = shift;
    my $subj  = shift;
    my ($cn)  = ($subj =~ m{CN=(.+?)(?:\s*[/,]\s*\S+=|\s*$)});
    return $cn;
}

1;

=head1 NAME

Socialtext::CredentialsExtractor::SSLCertificate - SSL Certificate credentials

=head1 DESCRIPTION

This plugin class trusts the credentials as provided by a Client-Side SSL
Certificate.

It is presumed that the "CN=" attribute in the Subject of the SSL Certificate
is the "username" for the User.

=head1 METHODS

=over

=item B<$extractor-E<gt>extract_credentials($request)>

Returns the Username as indicated in the Client-Side SSL Certificate.

=back

=head1 AUTHOR

Socialtext, Inc., C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Socialtext, Inc.,  All Rights Reserved.

=cut
