#!perl
use warnings;
use strict;
use Test::More tests => 10;
use AnyEvent;
use AnyEvent::Util qw/portable_socketpair/;
use Protocol::FastCGI qw/:const/;
use Socialtext::Async::FCGI;

my $all_done_cv = AE::cv;

sub server {
    my $fh = shift;
    my $cb = shift; # completion callback
    my %reqs;

    my $server_h = Socialtext::Async::FCGI->new(fh => $fh);

    $server_h->on_error(sub {
        my ($h,$fatal,$msg) = @_;
        $all_done_cv->croak("server: $msg (fatal? $fatal)\n");
    });

    $server_h->on_fcgi_begin(sub {
        my ($h,$req_id,$role,$flags) = @_;
        pass "server req begin";
        if ($role != FCGI_RESPONDER) {
            $server_h->fcgi_end($req_id, 1, FCGI_UNKNOWN_ROLE);
            $all_done_cv->croak("server: bad role $role\n");
        }

        $reqs{$req_id} = {
            input => '',
            params => undef,
        };
        $all_done_cv->begin;
        return sub {
            pass "server completion";
            delete $reqs{$req_id};
            $all_done_cv->end;
            $cb->();
        };
    });

    $server_h->on_fcgi_params(sub {
        my ($h,$req_id,$params) = @_;
        $reqs{$req_id}{params} = $params;
        $server_h->fcgi_write($req_id, FCGI_STDERR, "processing request...\n");
    });

    $server_h->on_fcgi_stream(sub {
        my ($h,$req_id,$type,$buf) = @_;
        if ($buf && length $$buf) {
            $reqs{$req_id}{input} .= $$buf;
        }
        else {
            $server_h->fcgi_write($req_id, FCGI_STDERR, "some log message\n");
            $server_h->fcgi_write($req_id, FCGI_STDOUT, \"HTTP/1.0 200 OK\r\n...");
            $server_h->fcgi_end($req_id, 0);
        }
    });

    return $server_h;
}

sub client {
    my $client_fh = shift;
    my $cb = shift; # completion callback
    my $stdout = '';
    my $stderr = '';

    my $client_h; $client_h = Socialtext::Async::FCGI->new(
        fh => $client_fh,
        fcgi_client_mode => 1,
        on_fcgi_stream => sub {
            my ($h,$req_id,$type,$buf) = @_;
            die "invalid request id $req_id" unless ($req_id == 42);
            if ($type == FCGI_STDOUT) {
                $stdout .= $$buf;
            }
            elsif ($type == FCGI_STDERR) {
                $stderr .= $$buf;
            }
        },
        on_fcgi_end => sub {
            my ($h,$req_id,$exit_code,$proto_status) = @_;
            die "invalid request id $req_id" unless ($req_id == 42);
            pass "client on req end";
            $all_done_cv->end;
            $cb->(\$stdout,\$stderr,$exit_code,$proto_status);
        },
    );

    $client_h->on_error(sub {
        my ($h,$fatal,$msg) = @_;
        $all_done_cv->croak("client: $msg (fatal? $fatal)\n");
    });

    $all_done_cv->begin;
    $client_h->fcgi_begin(42, {HTTP_METHOD => 'GET'});
    pass "client begun";
    $client_h->push_shutdown();

    return $client_h;
}

my ($client_fh,$server_fh) = portable_socketpair();
ok $client_fh && $server_fh, "created socketpair";

$all_done_cv->begin;
my $server_h = server($server_fh, sub {
    pass "server done";
    $all_done_cv->end;
});

$all_done_cv->begin;
my $client_h = client($client_fh, sub {
    my ($stdout_ref,$stderr_ref,$exit_code,$proto_status) = @_;
    ok $exit_code==0 && $proto_status==FCGI_REQUEST_COMPLETE, "client done";
    is $$stdout_ref, "HTTP/1.0 200 OK\r\n...";
    $all_done_cv->end;
});

my $timeout = AE::timer 5,0,sub {
    warn "test hung!";
    exit 2;
};

pass "receiving...";
$all_done_cv->recv;
undef $timeout;
pass "all finished";
