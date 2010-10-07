package Socialtext::Async::Wrapper;
# @COPYRIGHT@
use warnings;
use strict;
use Moose::Exporter ();
use Coro;
use Coro::State ();
use Coro::AnyEvent;
use Guard;
use AnyEvent::Worker;
use Carp qw/carp croak/;
use Scalar::Util qw/blessed/;
use Socialtext::Timer qw/time_scope/;
use Try::Tiny;
use Socialtext::TimestampedWarnings;
use BSD::Resource qw/setrlimit get_rlimits/;
use Socialtext::Log qw/st_log/;
use namespace::clean -except => 'meta';

=head1 NAME

Socialtext::Async::Wrapper - wrap code to run in a worker process.

=head1 SYNOPSIS

    use Moose;
    use Socialtext::Async::Wrapper;

    worker_function do_x => sub {
        my $input = shift;
        # ... runs in worker
        return alright => 'i was passed: '.$input;
    };
    my @result = do_x("something");

    worker_wrap replacement => 'Some::Slow::class_method';
    sub replacement {
        my $class = shift; # e.g. 'Some::Slow'
        # executes the original method in the worker:
        my $result = call_orig_in_worker(replacement => $class, @_);
    }
    # ... then elsewhere
    my $r = Some::Slow->class_method(param_a => 1, param_b => 2);

=head1 DESCRIPTION

Currently this library is Moose-y sugar around C<AnyEvent::Worker>.

Running "blocking" or "slow" code in a worker has two key advantages: it uses
another CPU core for speed and it doesn't block your evented daemon from doing
I/O tasks (like accepting new clients, receiving requests, sending responses).

The first call to a wrapped bit of code will launch the sub-process.

Calling a wrapped method will transmit arguments to the subprocess and receive
results (to the extent that C<Storable> and C<AnyEvent::Worker> can do so).  A
string exception will be thrown starting with "Worker shutdown: " if a
communication or other fatal error occurs.  Other exceptions are
passed-through as-is.

To affect startup and shutdown of the worker process, overload the
Socialtext::Async::Wrapper::Worker::BUILD and DEMOLISH methods.

To affect what happens before each request (e.g. cache clearing), override
Socialtext::Async::Wrapper::Worker::before_each.  before_each B<MUST NOT>
throw an exception.

=cut

Moose::Exporter->setup_import_methods(
    with_caller => [qw(worker_wrap worker_function)],
    as_is => [qw(worker_make_immutable call_orig_in_worker ping_worker)],
);

our $IN_WORKER = 0;
our @AT_FORK;
our $VMEM_LIMIT = 512 * 2**20; # MiB

=head1 CLASS METHODS

=over 4

=item C<< RegisterCoros() >>

Marks currently active Coros for non-deletion.  At fork, other Coros will be
cancelled.

=cut

sub RegisterCoros {
    # mark the current coros so we don't kill them in the sub-process.
    for my $coro (Coro::State::list()) {
         $coro->{_preserve_on_fork} = 1;
    }
}

=item C<< RegisterAtFork(sub { ... }) >>

Register some code to run after forking.  Will run after extraneous coros have
been cancelled but before any "standard" initializations the socialtext stack
needs.

=cut

sub RegisterAtFork {
    my $class = shift;
    push @AT_FORK, shift;
}

sub _InWorker {
    my $class = shift;

    # Prevents recursive workers:
    $IN_WORKER = 1;

    no warnings 'redefine';
    Socialtext::TimestampedWarnings->import;

    for my $coro (Coro::State::list()) {
        unless (
            $coro == $Coro::current ||
            $coro->{desc} =~ /^\[/ ||
            $coro->{_preserve_on_fork}
        ) {
            $coro->cancel;
        }
    }

    for my $fork_cb (@AT_FORK) {
        eval { $fork_cb->() };
    }

    # AnyEvent::Worker ignores SIGINT, un-ignore it so st-daemon-monitor
    # can kill us.
    $SIG{INT} = 'DEFAULT';

    # make it reconnect
    Socialtext::SQL::disconnect_dbh();

    # clear caches.
    Socialtext::Cache->clear();
    # but make sure it uses the user-cache until we clear it.
    $Socialtext::User::Cache::Enabled = 1;

    # st_log is disconnected by AnyEvent::Worker right after fork.
    # Reconnect it here.
    Sys::Syslog::disconnect();
    $Socialtext::Log::Instance = Socialtext::Log->_renew();

    # If something's messed up with Coro/Ev/AnyEvent this will fail:
    my $cv = AE::cv;
    my $t = AE::timer 0.0005, 0, sub {
        $cv->send("seems to be working");
    };
    my $ok = eval { $cv->recv };
    $ok ||= 'is broken';
    st_log()->info("in async worker $$, AnyEvent $ok");

    my $lim = $VMEM_LIMIT;
    if ($lim) {
        my $rlimits = get_rlimits();
        # limit Virtual Memory and Address Space
        for my $res (qw(RLIMIT_VMEM RLIMIT_AS)) {
            next unless exists $rlimits->{$res};
            setrlimit($rlimits->{$res}, $lim, $lim);
        }
    }
}

=back

=cut

{
    package Socialtext::Async::Wrapper::Worker;
    use Moose;
    use Try::Tiny;

    sub BUILD {
        my $self = shift;
        # This BUILD runs in the child worker process only.
        Socialtext::Async::Wrapper->_InWorker();
        return;
    }

    sub DEMOLISH {
        $Socialtext::Log::Instance->info("async worker $$ stopping");
    }

    sub before_each {
        try {
            # most of these copied from Socialtext::Handler::Cleanup
            Socialtext::Cache->clear();
            Socialtext::SQL::invalidate_dbh();
            File::Temp::cleanup();
        }
        catch {
            warn "in before_each: $_";
        };
        return;
    }

    sub worker_ping {
        my $self = shift;
        $self->before_each();
        Socialtext::SQL::get_dbh();
        $Socialtext::Log::Instance->debug("async worker is OK");
        return {'PING'=>'PONG'}
    }

    # other methods get installed here by worker_wrap and worker_function.

    no Moose; # remove sugar
}

=head1 EXPORTS

=over 4

=cut

=item worker_wrap replacement => 'Slow::Class::method';

Wrap some slow class-method so that it runs in a worker child process.  All
calls to that method are proxied to the worker.

The replacement should be a function in the current package.  It should call
C<call_orig_in_worker> after perhaps doing some parent-process caching.

=cut

sub worker_wrap {
    my $caller = shift;
    my $replacement = shift;
    my $method_to_wrap = shift;
    my %args = @_;

    no warnings 'redefine';
    no strict 'refs';

    (my $orig_pkg = $method_to_wrap) =~ s/::.+?$//;
    my $orig_method = \&{$method_to_wrap};
    my $worker_name = "worker_$replacement";
    my $replacement_method = \&{$caller.'::'.$replacement};

    # Install a method to call the original, "real" method.  This
    # worker_method will be called in the AnyEvent::Worker sub-process.
    my $worker_method = Moose::Meta::Method->wrap(
        name => $worker_name,
        package_name => 'Socialtext::Async::Wrapper::Worker',
        body => sub {
            my $self = shift;
            $self->before_each();
            my $t = time_scope $worker_name;
            my $class_or_obj = shift;
            return $class_or_obj->$orig_method(@_);
        },
    );
    Socialtext::Async::Wrapper::Worker->meta->add_method(
        $worker_name => $worker_method);

    # Swap in a replacement for the original method.  This replacement *must*
    # call the call_orig_in_worker() function.
    *{$method_to_wrap} = sub {
        # prevent recursive calls into additional workers
        if ($IN_WORKER) { goto $orig_method; }
        else { goto $replacement_method; }
    };
}

=item worker_function func_name => sub { ... }

Installs C<sub func_name { ... }> into the current package.  The supplied sub
will actually run in the worker process.

=cut

sub worker_function {
    my $caller = shift;
    my $name = shift;
    my $code = shift;

    my $worker_name = "worker_$name";
    my $worker_method = Moose::Meta::Method->wrap(
        name => $worker_name,
        package_name => 'Socialtext::Async::Wrapper::Worker',
        body => sub {
            my $self = shift; # instance of Socialtext::Async::Wrapper::Worker
            $self->before_each();
            my $t = time_scope $worker_name;
            shift; # undef
            return $code->(@_);
        },
    );
    Socialtext::Async::Wrapper::Worker->meta->add_method(
        $worker_name => $worker_method);

    my $method = Moose::Meta::Method->wrap(
        name => $name,
        package_name => $caller,
        body => sub {
            return call_orig_in_worker($name, undef, @_);
        },
    );

    my $meta = Class::MOP::Class->initialize($caller);
    $meta->add_method($name => $method);
    return;
}

=item worker_make_immutable

Make the Socialtext::Async::Wrapper::Worker package immutable (optimize the
worker for speed).  Call this after you've installed all the wrapped
methods/functions you need.

=cut

sub worker_make_immutable {
    Socialtext::Async::Wrapper::Worker->meta->make_immutable(
        inline_constructor => 1);
}

our $ae_worker;
sub _setup_ae_worker {
    die 'IO::AIO shouldnt be loaded' if $INC{'IO/AIO.pm'};
    st_log()->info("async worker starting...");

    my %parent_args = (
        on_error => sub {
            my ($w,$error,$fatal) = @_;
            warn(($fatal ? "fatal " : "") ."ae-worker error: $error\n");
            delete $ae_worker->{on_error}; # remove circular ref
            undef $ae_worker;
        },
        timeout => 30,
    );
    my %child_args = (
        class => 'Socialtext::Async::Wrapper::Worker',
    );

    my $old_desc = $Coro::current->{desc};
    my $coro = async {
        $Coro::current->{desc} = "AnyEvent::Worker";
        $ae_worker = AnyEvent::Worker->new(\%child_args, %parent_args);
    };
    $coro->cede_to;
    $coro->join;
}

=item call_orig_in_worker name => $class[, @params]

Calls the 'name' method installed by C<worker_wrap>, passing in optional
parameters.

=cut

# Used by the replacement method (executing in the parent) to invoke the
# "real" method in the Worker process.
sub call_orig_in_worker {
    my $replacement = shift;
    my $tgt_class = shift;
    $tgt_class = ref($tgt_class) if blessed $tgt_class;
    my $worker_method_name = "worker_$replacement";

    Carp::confess "Cannot call_orig_in_worker from within a worker"
        if $IN_WORKER;

    _setup_ae_worker() unless $ae_worker;

    my $cv = AE::cv;
    $ae_worker->do($worker_method_name => $tgt_class, @_, sub {
        my $wrkr = shift; # AnyEvent::Worker, but never a ::Pool
        if (my $e = $@) {
            if (!$wrkr->{fh}) {
                # fh is deleted for fatal errors
                $cv->croak("Worker shutdown: $e");
            }
            else {
                $cv->croak("Worker died: $e")
            }
        }
        else {
            $cv->send(\@_);
        }
    });
    # TODO pause all Socialtext::Timer while sleeping in coro
    my $result = $cv->recv; # may croak

    return unless ($result and defined wantarray);
    return wantarray ? @$result : $result->[0];
}

=item ping_worker

Calls the 'ping' method on the worker, dies if worker is unreachable or if the
result was corrupted somehow.

=cut

sub ping_worker {
    my $result = call_orig_in_worker('ping', undef);
    die "corrupted result" unless $result->{PING} eq 'PONG';
    return $result;
}

1;
__END__

=back

=head1 COPYRIGHT

(C) 2010 Socialtext Inc.
