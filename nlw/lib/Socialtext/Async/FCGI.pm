package Socialtext::Async::FCGI;
# @COPYRIGHT@
use warnings;
use strict;

use AnyEvent::Handle;
use Protocol::FastCGI qw/:all/;
use Carp qw/croak confess/;
use Guard qw/guard/;
use base 'AnyEvent::Handle';

# regular callbacks
sub on_fcgi_begin  { $_[0]{on_fcgi_begin}  = $_[1] }
sub on_fcgi_end    { $_[0]{on_fcgi_end}    = $_[1] }
sub on_fcgi_abort  { $_[0]{on_fcgi_abort}  = $_[1] }
sub on_fcgi_params { $_[0]{on_fcgi_params} = $_[1] }
sub on_fcgi_stream { $_[0]{on_fcgi_stream} = $_[1] }

# management callbacks
sub on_fcgi_get_values        { $_[0]{on_fcgi_get_values}        = $_[1] }
sub on_fcgi_get_values_result { $_[0]{on_fcgi_get_values_result} = $_[1] }
sub on_fcgi_unknown           { $_[0]{on_fcgi_unknown}           = $_[1] }

sub new {
    my $class = shift;
    my %p = @_;

    $p{fcgi_client_mode} ||= 0;
    $p{fcgi_reqs} = {
        MANAGEMENT_REQ_ID+0 => {ended => undef, flags => FCGI_KEEP_CONN},
    };
    $p{fcgi_wq} = []; # post-drain write queue
    $p{fcgi_real_drain} = undef;

    $p{on_read} = \&_fcgi_on_read;
    $p{on_eof} ||= sub {}; # ignore eof
    $p{low_water_mark} = 0;

    return $class->SUPER::new(%p);
}

sub _fcgi_on_read {
    my $self = shift;
    my $rbuf = \$self->{rbuf};
    return unless (length($rbuf) >= FCGI_HEADER_LEN);
    my ($type,$req_id,@content) = decode_one_record($rbuf);
    return unless defined $type;
    $self->_fcgi_reader($req_id,$type,@content);
    return;
}

sub _fcgi_new_req {
    my ($self,$req_id,$role,$flags) = @_;
    return $self->{fcgi_reqs}{$req_id} = {
        params => '',
        wrote  => [],
        role   => $role,
        flags  => $flags,
        ended  => undef,
        obj    => undef,
        completion_cb => undef,
        completion_cb_guard => undef,
    };
}

sub object_for_fcgi_req {
    my ($self, $req_id) = @_;
    return $self->{fcgi_reqs}{$req_id}{obj};
}

sub _fcgi_reader {
    my $self = shift;
    my $req_id = shift;
    my $type = shift;

    #warn "_fcgi_reader $req_id $type $self->{fcgi_client_mode}";

    my $req = $self->{fcgi_reqs}{$req_id};

    if ($type == FCGI_BEGIN_REQUEST) {
        my $role = shift;
        my $flags = shift;

        if ($self->{fcgi_client_mode}) {
            $self->_error(Errno::EBADMSG(), 0,
                "FCGI_BEGIN_REQUEST received in client mode");
            return;
        }
        if (exists $self->{fcgi_reqs}{$req_id}) {
            $self->_error(Errno::EBADMSG(), 0,
                "duplicate FCGI_BEGIN_REQUEST for $req_id");
            return;
        }

        $req = $self->_fcgi_new_req($req_id,$role,$flags);

        my $begin = $self->{on_fcgi_begin};
        if ($begin) {
            my ($comp_cb,$obj) = $begin->($self,$req_id,$role,$flags);
            if ($comp_cb) {
                $req->{completion_cb} = $comp_cb;
                $req->{completion_cb_guard} = guard { $comp_cb->(1) };
            }
            $req->{obj} = $obj;
            delete $self->{fcgi_reqs}{$req_id} if $req->{ended};
        }
        return;
    }

    # management record
    if ($req_id == MANAGEMENT_REQ_ID) {
        return $self->_fcgi_mgmt_record($type,@_);
    }

    # regular record must be mapped to a request at this point
    if (!$req) {
        $self->_error(Errno::EBADMSG(), 0, "unknown request ID $req_id");
        return;
    }

    $self->_fcgi_dispatch_record($type,$req_id,$req,@_);
    return;
}

sub _fcgi_mgmt_record {
    my $self = shift;
    my $type = shift;
    if ($type == FCGI_UNKNOWN_TYPE) {
        my $cb = $self->{on_fcgi_unknown};
        $cb->($self,shift) if $cb;
    }
    elsif ($type == FCGI_GET_VALUES) {
        my $cb = $self->{on_fcgi_get_values};
        my $result = $cb->($self,unpack_nvpairs(shift)) if $cb;
        $self->fcgi_write(0, FCGI_GET_VALUES_RESULT, $result) if $result;
    }
    elsif ($type == FCGI_GET_VALUES_RESULT) {
        my $cb = $self->{on_fcgi_get_values_result};
        $cb->($self,unpack_nvpairs(shift)) if $cb;
    }
    else {
        $self->_error(Errno::EBADMSG(), 0,
            "invalid record type $type sent over req_id 0");
    }
    return;
}

sub _fcgi_dispatch_record {
    my $self = shift;
    my $type = shift;
    my $req_id = shift;
    my $req = shift;
    if ($type == FCGI_STDIN || $type == FCGI_STDOUT ||
        $type == FCGI_STDERR || $type == FCGI_DATA)
    {
        if (my $cb = $self->{on_fcgi_stream}) {
            $cb->($self,$req_id,$type,shift);
        }
    }
    elsif ($type == FCGI_PARAMS) {
        if (my $cb = $self->{on_fcgi_params}) {
            my $param_buf = shift;
            if ($param_buf && length($$param_buf)) {
                $req->{params} .= $$param_buf;
            }
            else {
                my $nvs = unpack_nvpairs(\delete $req->{params});
                $cb->($self,$req_id,$nvs);
            }
        }
    }
    elsif ($type == FCGI_ABORT_REQUEST) {
        if (my $cb = $self->{on_fcgi_abort}) {
            $cb->($self,$req_id);
        }
        delete $self->{fcgi_reqs}{$req_id};
    }
    elsif ($type == FCGI_END_REQUEST) {
        if (my $cb = $self->{on_fcgi_end}) {
            my $exit_code = shift;
            my $proto_status = shift;
            $cb->($self,$req_id,$exit_code,$proto_status);
            delete $self->{fcgi_reqs}{$req_id}
                unless $req_id == MANAGEMENT_REQ_ID;
        }
    }
    else {
        $self->_error(Errno::EBADMSG(), 0,
            "invalid record type $type read for request $req_id");
    }

}

# disable these methods
sub push_write     { return; }
sub low_water_mark { return; }
sub on_read        { return; }

sub push_shutdown {
    my $self = shift;
    delete $self->{fcgi_reqs}{MANAGEMENT_REQ_ID+0};
    $self->SUPER::push_shutdown();
}

sub on_drain {
    my ($self,$cb) = @_;

    $self->{fcgi_real_drain} = $cb;

    if ($cb && !$self->{on_drain}) {
        $self->SUPER::on_drain(\&_fcgi_drain);
    }
}

sub _fcgi_finished {
    my ($self, $shutdown) = @_;
    #warn "_fcgi_finished $self->{fcgi_client_mode}";
    if ($shutdown) {
        shutdown($self->{fh}, 2); # total shutdown
        $self->{fcgi_real_drain}->($self) if $self->{fcgi_real_drain};
        return $self->destroy;
    }
    delete $self->{fcgi_reqs}{MANAGEMENT_REQ_ID+0};
    return;
}

sub _fcgi_encode {
    my $self = shift;
    my $req_id = shift;
    my $type = shift;

    my @pkts;
    if ($type == FCGI_BEGIN_REQUEST) {
        return \join('',encode_begin($req_id,shift,shift));
    }
    elsif ($type == FCGI_ABORT_REQUEST) {
        return \join('',encode_abort($req_id));
    }
    elsif ($type == FCGI_END_REQUEST) {
        return \join('',encode_end($req_id,shift,shift));
    }
    elsif ($type == FCGI_STDIN || $type == FCGI_DATA ||
           $type == FCGI_STDOUT || $type == FCGI_STDERR)
    {
        return \join('',encode_stream($type,$req_id,@_));
    }
    elsif ($type == FCGI_PARAMS) {
        return \join('',encode_params($req_id,shift));
    }
    elsif ($type == FCGI_GET_VALUES) {
        return \join('',encode_get_values(shift));
    }
    elsif ($type == FCGI_GET_VALUES_RESULT) {
        return \join('',encode_get_values_result(shift));
    }
    elsif ($type == FCGI_UNKNOWN_TYPE) {
        return \join('',encode_unknown(shift));
    }
    else {
        croak "anyevent fcgi write: invalid record type $type\n";
    }

    return;
}

sub _fcgi_drain {
    my $self = shift;
    #warn "_fcgi_drain $self->{fcgi_client_mode}";

    my $q = $self->{fcgi_wq};
    if ($self->{fcgi_client_mode} || !@$q) {
        $self->{fcgi_real_drain}->($self) if $self->{fcgi_real_drain};
        return;
    }

    # first item on the queue should always be a completion event entry
    confess "assertion failed: first element of write queue isn't a request id"
        if ref($q->[0]);
    my $req_id = shift @$q;
    if (my $req = $self->{fcgi_reqs}{$req_id}) {
        delete $self->{fcgi_reqs}{$req_id}
            unless $req_id == MANAGEMENT_REQ_ID; # not the control req

        if (my $cb = $req->{completion_cb}) {
            $req->{completion_cb_guard}->cancel();
            $cb->(0);
        }

        unless ($req->{flags} & FCGI_KEEP_CONN) {
            # last request on the socket
            return $self->_fcgi_finished(1);
        }
    }

    if (!@$q) {
        if ($self->{_eof}) {
            # no more output, read-side of socket went EOF
            return $self->_fcgi_finished(1);
        }

        $self->{fcgi_wq} = []; # reallocate queue to prevent perl leaks

        # disable the drain handler unless there's a real drain callback
        $self->SUPER::on_drain() unless $self->{fcgi_real_drain};
    }

    # push_write while there are arrayref entries on the queue
    while (@$q && ref($q->[0])) {
        my $write = shift @$q;
        #warn "drain write $self->{fcgi_client_mode}";
        $self->SUPER::push_write($$write);
    }

    return;
}

sub fcgi_write {
    my $self = shift;
    my $req_id = shift;
    my $type = shift;
    # next on stack: contents

    #warn "fcgi_write $type $self->{fcgi_client_mode}";

    my $req = $self->{fcgi_reqs}{$req_id};
    return unless $req && !$req->{ended};

    if ($type == FCGI_STDIN || $type == FCGI_STDOUT ||
        $type == FCGI_STDERR || $type == FCGI_DATA)
    {
        $req->{wrote}[$type] ||= defined $_[0] ? 1 : undef;
    }

    my $buf = $self->_fcgi_encode($req_id, $type, @_);
    if (@{$self->{fcgi_wq}}) {
        # waiting for a request to drain; queue up this write for later
        #warn "fcgi write is buffering";
        push @{$self->{fcgi_wq}}, $buf;
    }
    else {
        $self->SUPER::push_write($$buf);
    }
    return;
}

sub fcgi_end {
    my $self = shift;
    my $req_id = shift;
    my $exit_code = shift || 0;
    my $proto_status = shift || FCGI_REQUEST_COMPLETE;
    
    return unless $req_id;

    my $req = $self->{fcgi_reqs}{$req_id};
    return unless $req && !$req->{ended};

    my $req_wrote = $req->{wrote};

    for my $stream (FCGI_STDIN,FCGI_DATA,FCGI_STDOUT,FCGI_STDERR) {
        next unless $req_wrote->[$stream];
        #warn "flushing $stream $self->{fcgi_client_mode}";
        $self->fcgi_write($req_id, $stream); # flush
    }
    #warn "end request $self->{fcgi_client_mode}";
    return if $self->{fcgi_client_mode};

    $self->fcgi_write($req_id,FCGI_END_REQUEST,$exit_code,$proto_status);
    $req->{ended} = 1;

    push @{$self->{fcgi_wq}}, $req_id;
    $self->SUPER::on_drain(\&_fcgi_drain) unless $self->{on_drain};
    return;
}

sub fcgi_begin {
    my $self = shift;
    my $req_id = shift;
    my $params = shift;
    my $role = shift || FCGI_RESPONDER;
    my $flags = shift || 0;

    die "can't begin a request unless in client mode"
        unless $self->{fcgi_client_mode};

    #warn "begin $req_id $self->{fcgi_client_mode}";

    my $req = $self->_fcgi_new_req($req_id,$role,$flags);

    # send the request header and params
    $self->fcgi_write($req_id, FCGI_BEGIN_REQUEST, $role, $flags);
    $self->fcgi_write($req_id, FCGI_PARAMS, $params);

    # auto-flush if it's a entity-less request.
    if ($params->{HTTP_METHOD} =~ /^(?:HEAD|GET|DELETE|TRACE)$/) {
        $req->{wrote}[FCGI_STDIN] = 1; # so that STDIN gets flushed
        $self->fcgi_end($req_id);
    }
    return;
}

1;
__END__

=head1 NAME

Socialtext::Async::FCGI - Subclass AnyEvent::Handle for handling FCGI

=head1 SYNOPSIS

  use Socialtext::Async::FCGI;
  my $fh = accept($listen_socket); # ykwim
  my $h = Socialtext::Async::FCGI->new(
    fh => $fh,
    on_fcgi_begin => sub {},
    on_fcgi_stream => sub {},
    ...
  );

=head1 DESCRIPTION

Frame FastCGI (FCGI) packets using Protocol::FastCGI, with AnyEvent async
goodness.  The sending and receiving can be made non-blocking for both clients
and servers.

=head1 METHODS

=over 4

=item new(...)

Accepts all AnyEvent::Handle arguments.  With a few exceptions and additions

=over 8

=item low_water_mark

Always zero; cannot change.

=item on_drain

Should work as expected, however this module will "chain" the callback to
handle per-request-id "drain" events when multiplexing requests over a single
socket.  This includes calls to C<push_shutdown>.

=item on_eof

Ignored by default, but callers may specify one.

=item on_read

Ignored; this module installs its own.  Use the C<on_fcgi_*> callbacks
instead.

=back

Additional FCGI parameters.

=over 8

=item fcgi_client_mode => (0|1)

Put this object into client mode (default is server/application mode)

=back

FCGI callbacks.  Can be called as methods or passed as arguments to new() to
assign a new handler.  The callback parameters use the same convention here as
in the C<AnyEvent::Handle> documentation.

=over 8

=item on_fcgi_begin => $cb->($h,$req_id,$role,$flags)

For FCGI servers, begin a new FCGI request (no params yet). FCGI requests have
a 1:1 correspondence with HTTP requests, generally.

Must return a pair of items: a completion callback (called when the request
has been "flushed" to the peer) and an object reference (which can be null).
These two references are kept until the request is flushed or aborted.  The
callback will be called with a C<$cancelled> parameter; false for success, true
for cancellation.

Use C<< $h->object_for_fcgi_req($req_id) >> to retrieve the object in other
callbacks.

=item on_fcgi_end => $cb->($h,$req_id,$exit_code,$proto_status)

For FCGI clients, an FCGI request has been completed.

=item on_fcgi_abort => $cb->($h,$req_id)

For FCGI servers, the client (web server) is notifying you of an HTTP request
cancellation.  After this handler is called, the completion callback returned
from your C<on_fcgi_begin> handler for the request will get called with a true
(cancelled) value.

=item on_fcgi_params => $cb->($h,$req_id,$params)

For FCGI servers, a complete C<FCGI_PARAMS> stream has arrived.  The parsed
hash table of params is passed to the callback.  This is analagous to the
C<%ENV> in CGI and SCGI.

Note that clients do B<not> receive params, but need to parse out headers from
the C<FCGI_STDOUT> stream.

=item on_fcgi_stream => $cb->($h,$req_id,$type,\$data)

For FCGI clients and servers, a chunk of data has arrived on the specified
stream. An empty or undef C<$data> argument means "end-of-stream".

Use C<fcgi_write> to write to streams.

=item on_fcgi_get_values => $cb->($h,$get_vals)

For FCGI servers, a C<FCGI_GET_VALUES> request has arrived.  The callback is
expected to return a hash reference with the response (OK to fill in
$get_vals).  The callback is not passed a request ID since this event always
happens for the "management" of an FCGI process.

=item on_fcgi_get_values_result => $cb->($h,$result)

For FCGI clients, a C<FCGI_GET_VALUES_RESULT> response has arrived. The result
is passed in as a hashref.

=item on_fcgi_unknown => $cb->($h)

For both FCGI clients and servers, a C<FCGI_UNKNOWN> record has arrived.  NB
that "unknown" is a special type in FastCGI and doesn't mean "unexpected" or
"invalid".  Like C<on_fcgi_get_values>, this is not passed a request ID
because it's a "management" event.

=back

=item push_shutdown()

Begin shutting down the socket; calls the superclass' <push_shutdown> method
(which registers an on_drain handler to call C<shutdown> on the socket).

=item push_write(...)

Disabled in this subclass; no-op.  Use C<fcgi_write>, C<fcgi_begin> and
C<fcgi_end> instead.

=item object_for_fcgi_req($req_id)

Retrieve the object returned by the C<on_fcgi_begin> handler for this request
ID.

=item fcgi_write($req_id, $type, ...)

=item fcgi_write($req_id, FCGI_STDOUT, \"some http response")

=item fcgi_write($req_id, FCGI_STDERR, "some", "log", "message\n");

Uses the arguments to compose the FCGI frames using C<Protocol::FastCGI> then
schedules those frames for writing to the actual socket.

See the C<Protocol::FastCGI> docs for the different calling conventions (Look
at the ":encode" functions).  For the four stream types
(STDIN,DATA,STDOUT,STDERR), just pass in scalars to send via that stream.  All
four of the calls below will write the same thing to STDERR.

   $h->fcgi_write($req_id, FCGI_STDERR, "some data");
   $h->fcgi_write($req_id, FCGI_STDERR, \"some data");
   $h->fcgi_write($req_id, FCGI_STDERR, "some ", "data");
   $h->fcgi_write($req_id, FCGI_STDERR, ["some ", "data"]);

Any of those four streams that are written two will be "flushed" when
C<fcgi_end> gets called.

=item fcgi_end($req_id)

=item fcgi_end($req_id, [$exit_code || 0], [$proto_status])

For FCGI servers, indicate the end of a response.  This method will
automatically flush any of the four primary data streams if they were written
to.

An exit code of 0 indicates success, any other value (up to 255) to indicate
failure (think of this paramater like a call to C<exit> in a normal script).
See the FCGI spec and the C<Protocol::FastCGI> docs for the C<$proto_status>
parameter.

For FCGI clients, this method just flushes any streams that were written to.

=item fcgi_begin($req_id, [$role || FCGI_RESPONDER], [$flags])

For FCGI clients, send an FCGI_BEGIN_REQUEST frame for the specified role.

The C<$flags> parameter may be set to C<FCGI_KEEP_CONN> to indicate that more
requests will be sent over this socket.

=back

=cut
