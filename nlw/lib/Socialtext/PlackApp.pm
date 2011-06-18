package Socialtext::PlackApp;
use 5.12.0;
use parent 'Exporter';
our @EXPORT = 'PerlHandler';

use signatures;
use CGI::PSGI;
use URI;
use Log::Dispatch;
use Module::Load;
use HTTP::Status ();
use Encode ();

our ($Request, $Response);

sub PerlHandler ($handler) {
    load($handler);

    return sub ($env) {
        delete $env->{"psgix.io"};

        local $Request = Socialtext::PlackApp::Request->new($env);
        local $Response = Socialtext::PlackApp::Response->new(200);

        my $app = $handler->can('new') ? $handler->new(
            request => $Request,
            query => CGI::PSGI->new($env),
        ) : $handler;

        local %ENV = (%ENV, REST_APP_RETURN_ONLY => 1);
        map { $ENV{$_} = $env->{$_} }
            grep { /^(?:HTTP|QUERY|REQUEST|REMOTE|SCRIPT|PATH|CONTENT|SERVER)_/ }
            keys %{$env};

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
    @Apache::Constants::ISA = 'Exporter';
    $INC{$_} = __FILE__ for qw(
        Apache/Cookie.pm
        Apache/Request.pm
        Apache/Constants.pm
        Apache/SubProcess.pm
        Apache/URI.pm
        Apache.pm
    );
    my %synonyms = (
        FOUND => 'REDIRECT',
        UNAUTHORIZED => 'AUTH_REQUIRED',
    );

    for my $method (@{$HTTP::Status::EXPORT_TAGS{constants}}) {
        no strict 'refs';
        (my $code = $method) =~ s/^HTTP_//;
        my $value = &{"HTTP::Status::$method"}();
        *{"Apache::Constants::$code"} = sub { $value };
        push @Apache::Constants::EXPORT, $code;
        if (my $sym = $synonyms{$code}) {
            *{"Apache::Constants::$sym"} = sub { $value };
            push @Apache::Constants::EXPORT, $sym;
        }
    }
    %Apache::Constants::EXPORT_TAGS = (
        common => \@Apache::Constants::EXPORT,
        response => \@Apache::Constants::EXPORT,
    );
    *URI::unparse = *URI::as_string;
}

package Socialtext::PlackApp::Cookie;
use parent 'CGI::Cookie';
use namespace::autoclean;
use invoker;
use Method::Signatures::Simple;

*Response = *Socialtext::PlackApp::Response;
method new (%opts) {
    delete $opts{'-expires'} unless $opts{'-expires'};
    $->SUPER::new(%opts);
}
method bake {
    $Response->header('Set-Cookie', $->as_string);
}

package Socialtext::PlackApp::Connection;
use parent 'Class::Accessor';
__PACKAGE__->mk_accessors(qw(user));

package Socialtext::PlackApp::Response;
use parent 'Plack::Response';
use namespace::autoclean;
use invoker;
use Method::Signatures::Simple;
method err_headers_out { $self }
method add { $->header(\@_) }

package Socialtext::PlackApp::Request;
use parent 'Plack::Request';
use namespace::autoclean;
use invoker;
use Method::Signatures::Simple;
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
        return uri_unescape($->SUPER::uri->path);
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

1;
