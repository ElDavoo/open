package Socialtext::EventDaemon::Request;
# @COPYRIGHT@
use Moose;
use MooseX::AttributeHelpers;

use Coro;
use AnyEvent;
use Coro::AnyEvent;

use HTTP::Headers ();
use HTTP::Response ();

use Socialtext::Log qw/st_timed_log st_log/;
use Socialtext::Async::Syslog; # monkey-patches Socialtext::Log & stuff

use Socialtext::Encode;
use Socialtext::HTTP ':codes';
use Socialtext::JSON qw(encode_json decode_json);
use Socialtext::String;
use Socialtext::HTTP::Ports;
use Socialtext::HTTP::Cookie;
use Socialtext::AppConfig;
use Socialtext::Paths;

use Socialtext::EventDaemon::Events;

use namespace::clean -except => 'meta';

our $VERSION = '2.5';
use constant ACCEPT_TYPE => 'application/json; charset=UTF-8';

# Set up AppConfig so that it only loads once so we don't block on it.
{
    $Socialtext::AppConfig::Auto_reload = 0;
    my $appconfig = Socialtext::AppConfig->instance();
}

my $process_start = AnyEvent->time;
our $ticker = AE::timer 0, 600, sub {
    Socialtext::Log::st_log("info", "event-daemon uptime ".
        sprintf('%0.3f seconds', AnyEvent->time - $process_start));
};

has env => (
    metaclass => 'Collection::Hash',
    is => 'ro', isa => 'HashRef', required => 1,
    curries => {
        get => {
            request_method => ['REQUEST_METHOD'],
            cookie         => ['HTTP_COOKIE'],
        },
    },
);

has handle => (
    is => 'ro', isa => 'AnyEvent::Handle', required => 1,
);

has content => (
    is => 'ro', isa => 'Maybe[ScalarRef]', required => 1,
);

has started => (
    is => 'rw', isa => 'Num',
);
has timers => (
    is => 'rw', isa => 'HashRef', default => sub { +{} },
);
has done => (
    is => 'rw', isa => 'Bool', default => undef,
    reader => 'is_done', writer => 'done',
);

has request_status => (
    is => 'rw', isa => 'Str', default => '???'
);
has response_body => (
    is => 'rw', isa => 'ScalarRef', init_param => undef,
);

has params => (
    metaclass => 'Collection::Hash',
    is => 'ro', isa => 'HashRef', lazy_build => 1, init_param => undef,
    provides => {
        get => 'param',
    },
    curries => {
        get => {
            proxy_timeout  => ['stTimeout'],
        },
    },
);

sub _build_params {
    my $self = shift;
    my %params;
    if ($self->request_method eq 'GET') {
        my $data = \$self->env->{QUERY_STRING};
        for (split /[&;]/, $$data) {
            my ($key, $val) = split '=';
            $params{$key} = Socialtext::String::uri_unescape($val);
        }
    }
    return {
        %params,
    }
}

has validated_user_id => (
    is => 'ro', isa => 'Maybe[Int]', lazy_build => 1,
);
sub _build_validated_user_id {
    my $self = shift;
    return undef unless $self->cookie;
    local $ENV{HTTP_COOKIE} = $self->cookie;
    my $start = AnyEvent->time;
    my $id = Socialtext::HTTP::Cookie->GetValidatedUserId;
    $self->timers->{validate} = AnyEvent->time - $start;
    return $id;
}

sub error_response {
    my $self = shift;
    my $code = shift;
    my $status = shift;
    my $msg = shift;

    my $header = HTTP::Headers->new(
        'Status' => $status,
        'Content-Type' => 'text/plain',
        'Connection' => 'close',
        @_
    );

    my $h = $self->handle;
    $h->push_write($header->as_string . "\r\n$msg");
    $h->push_shutdown();
    $self->request_status($code);
    $h->on_drain($self->make_log_cb());
    $self->done(1);
    return;
}

sub server_error {
    my $self = shift;
    my $error = shift;
    return $self->error_response(500, HTTP_500_Internal_Server_Error,
        "Server Error: $error"
    );
}

sub forbidden {
    my $self = shift;
    return $self->error_response(403, HTTP_403_Forbidden, "Forbidden");
}

has response_headers => (
    metaclass => 'Collection::Hash',
    is => 'rw', isa => 'HashRef',
    lazy_build => 1,
    auto_deref => 1,
    init_param => undef,
    provides => {
        set => 'set_response_header',
        get => 'get_response_header',
    },
    curries => {
        set => {
            set_content_type => ['Content-Type'],
            set_status       => ['Status'],
            set_x_cached     => ['X-Cache'],
        },
    },
);
sub _build_response_headers {
    my $self = shift;
    return { 
        'Status' => HTTP_200_OK,
        'Content-Type' => ACCEPT_TYPE,
    };
}

sub build_response {
    my $self = shift;
    return if $self->is_done;

    $self->set_status(HTTP_200_OK);

    my %headers = $self->response_headers;
    my $header = HTTP::Headers->new(
        %headers,
        'Connection' => 'close',
    );

    my $h = $self->handle;
    $h->push_write($header->as_string . "\r\n");
    $h->push_write(${$self->response_body});
    $h->push_shutdown;
    #$h->on_drain($self->make_log_cb());
    $h->on_drain(unblock_sub {
        my $handle = shift;
        $handle->destroy;
    });
    $self->done(1); # all done
    return;
}

sub make_log_cb {
    my $self = shift;

    my $started = $self->started;
    my $user_id = $self->validated_user_id;
    my $size = defined($self->response_body)
        ? length(${ $self->response_body })
        : '0';

    my $timers = $self->timers;

    # NOTE: don't put any references to $self in the following sub so it can
    # get GC'd.
    $self = undef;
    return unblock_sub {
        my $handle = shift;
        $handle->destroy;
        $timers->{overall} = AnyEvent->time - $started;
        st_timed_log(
            'info', 'EVENTDAEMON', $user_id,
            { map { $_ => sprintf('%0.3f',$timers->{$_}) } keys %$timers },
        );
    };
}

sub do_fetch_events {
    my $self = shift;
    my $start = AnyEvent->time;
    my $events = Socialtext::EventDaemon::Events->Get(
        user_id => $self->validated_user_id,
    );
    $self->response_body(\encode_json($events));
    $self->timers->{fetch} = AnyEvent->time - $start;
    return 1;
}

sub do_post_event {
    my $self = shift;
    my $start = AnyEvent->time;
    my $content = decode_json(${$self->content});
    my $events = Socialtext::EventDaemon::Events->Put($content);
    $self->response_body(\'Added');
    $self->timers->{post} = AnyEvent->time - $start;
    return 1;
}

sub handle_request {
    my $self = shift;
    $self->started(AnyEvent->time);

    return $self->forbidden unless $self->validated_user_id;

    my $ok;
    if ($self->request_method eq 'GET') {
        $ok = $self->do_fetch_events();
    }
    elsif ($self->request_method eq 'PUT') {
        $ok = $self->do_post_event();
    }
    else {
        return $self->error_response(405, "Method Not Allowed");
    }

    return unless $ok;
    return $self->build_response();
}

sub cancel {
    my $self = shift;
    my $fatal = shift;
    my $msg = shift;
    return if $self->is_done;
    eval {
        $self->server_error("AnyEvent::Handle error: $msg");
    };
    $self->done(1);
    $self->request_status('cancelled'); # for logging
}

__PACKAGE__->meta->make_immutable;
1;
