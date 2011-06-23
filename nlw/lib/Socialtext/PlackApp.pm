package Socialtext::PlackApp;
use 5.12.0;
use parent 'Exporter';
our @EXPORT = 'PerlHandler';

use signatures;
use CGI::PSGI;
use URI;
use Log::Dispatch;
use Module::Load;
use Encode ();
use Apache::Constants qw(:response);

our ($Request, $Response, $CGI);

sub PerlHandler ($handler, $access_handler) {
    load($handler);

    return sub ($env) {
        delete $env->{"psgix.io"};

        local $Request = Socialtext::PlackApp::Request->new($env);
        local $Response = Socialtext::PlackApp::Response->new(200);
        local $CGI = CGI::PSGI->new($env);

        my $app = $handler->can('new') ? $handler->new(
            request => $Request,
            query => $CGI,
        ) : $handler;

        local %ENV = (%ENV, REST_APP_RETURN_ONLY => 1);
        map { $ENV{$_} = $env->{$_} }
            grep { /^(?:HTTP|QUERY|REQUEST|REMOTE|SCRIPT|PATH|CONTENT|SERVER)_/ }
            keys %{$env};

        if ($access_handler) {
            load $access_handler;
            my $rv = $access_handler->can('handler')->($Request);
            if ($rv != OK) {
                $Response->status($rv);
                return $Response->finalize;
            }
        }

        my ($h, $out) = $app->handler($Request);

        # Copied from Socialtext::CleanupHandler:
        use Socialtext::Cache ();
        use Socialtext::SQL ();
        Socialtext::Cache->clear();
        File::Temp::cleanup();
        Socialtext::SQL::invalidate_dbh();
        @Socialtext::Rest::EventsBase::ADD_HEADERS = ();

        if (!defined $out) {
            # A simple status is returned
            $Response->status($h || 200);
            return $Response->finalize;
        }

        my @headers = $h->header;
        $Response->content_type('text/html; charset=UTF-8');

        while (my $key = shift @headers) {
            my $val = shift @headers;
            $key =~ s/^-//;
            given (lc $key) {
                when ('status') {
                    $Response->status(int($val) || 200);
                    next;
                }
                when ('type') {
                    $Response->content_type($val);
                    next;
                }
            }
            $Response->header($key => $val);
        }

        Encode::_utf8_off($out);
        $Response->body($out);
        return $Response->finalize;
    }
};

### Apache method overrides ###
sub Apache::Cookie::new { shift; shift; Socialtext::PlackApp::Cookie->new(@_) }
sub Apache::Cookie::fetch { @_ ? $Request->cookies->{$_[0]} : $Request->cookies }
sub Apache::request { $Request }
sub Apache::Request::new { $Request }
sub Apache::Request::instance { $Request }

BEGIN {
    $INC{$_} = __FILE__ for qw(
        Apache/Cookie.pm
        Apache/Request.pm
        Apache/SubProcess.pm
        Apache/URI.pm
        Apache.pm
    );
    *URI::unparse = *URI::as_string;
}

package Socialtext::PlackApp::Cookie;
use parent 'CGI::Cookie';
use methods;
use invoker;

*Response = *Socialtext::PlackApp::Response;
method new (%opts) {
    delete $opts{'-expires'} unless $opts{'-expires'};
    $->SUPER::new(%opts);
}
method bake {
    $Response->err_headers_out->add('Set-Cookie', $->as_string);
}

package Socialtext::PlackApp::Connection;
use parent 'Class::Accessor';
__PACKAGE__->mk_accessors(qw(user));

package Socialtext::PlackApp::Response;
use parent 'Plack::Response';
use methods;
use invoker;
method err_headers_out { $self }
method add ($key, $val) {
    if ($key eq 'Set-Cookie') {
        $val .= '; HttpOnly';
    }
    $->header($key, $val);
}

package Socialtext::PlackApp::Request;
use parent 'Plack::Request';
use methods;
use invoker;
use Encode ();
use URI::Escape;
no warnings 'redefine';

*Response = *Socialtext::PlackApp::Response;

method content_type {
    if (@_) {
        return $Response->content_type(@_);
    }
    $->SUPER::content_type();
}

method uri {
    if (caller =~ /^Socialtext::/) {
        my $path = $->SUPER::uri->path;
        return Encode::decode_utf8(Encode::encode(latin1 => $path));
    }
    $->SUPER::uri();
}

method print {
    Encode::_utf8_off($_) for @_;
    $Response->body(@_);
}

method header_out {
    Encode::_utf8_off($_) for @_;
    $Response->header(@_);
}

method send_http_header { undef }
method prev { undef }
method header_in ($key) { scalar $->header($key) }
method args { %{ $->parameters } }
method content { wantarray ? () : $->SUPER::content }
method cgi_env { %ENV }
method parsed_uri { URI->new($ENV{REQUEST_URI}) }
method log_error { warn @_ }
method connection { $self->{_connection} //= Socialtext::PlackApp::Connection->new }

__END__

=head1 NAME

Socialtext::PlackApp - Plack adapter to Socialtext Handlers

=head1 SYNOPSIS

    use Plack::Builder;
    use Socialtext::PlackApp;
    builder {
        mount '/nlw/control' => PerlHandler('Socialtext::Handler::ControlPanel'),
        mount '/nlw' => PerlHandler('Socialtext::Handler::Authen'),
        mount '/' => PerlHandler('Socialtext::Handler::REST'),
    }

=head1 DESCRIPTION

This module exports a single function, C<PerlHandler>, that takes a
L<Socialtext::Handler> subclass and returns a Plack application for it.

=cut
