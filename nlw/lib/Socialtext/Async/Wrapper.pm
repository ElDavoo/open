package Socialtext::Async::Wrapper;
# @COPYRIGHT@
use warnings;
use strict;
use Moose::Exporter ();
use Coro;
use Coro::AnyEvent;
use Guard;
use AnyEvent::Worker;
use Carp qw/carp croak/;
use Scalar::Util qw/blessed/;
use Socialtext::Timer qw/time_scope/;
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
results (to the extent that C<Storable> and C<AnyEvent::Worker> can do so).

=head1 EXPORTS

=over 4

=cut

Moose::Exporter->setup_import_methods(
    with_caller => [qw(worker_wrap worker_function)],
    as_is => [qw(worker_make_immutable call_orig_in_worker ping_worker)],
);

our $IN_WORKER = 0;

{
    package Socialtext::Async::Wrapper::Worker;
    use Moose;

    # This BUILD runs in the child worker process only.
    sub BUILD {
        no warnings 'redefine';

        # prevent recursive worker invocations
        $Socialtext::Async::Wrapper::IN_WORKER = 1;

        # make it reconnect; AE::Worker disconnects it anyway
        Socialtext::SQL::disconnect_dbh();

        # clear caches.
        Socialtext::Cache->clear();

        # TODO: st_log is disconnected by AnyEvent::Worker right after fork.
        # Reconnect it here.

        return;
    }

    sub worker_ping { return {'PING'=>'PONG'} }

    # other methods get installed here by worker_wrap and worker_function.

    no Moose; # remove sugar
}

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
            scope_guard { Socialtext::Cache->clear };
            my $t = time_scope $worker_name;
            shift; # instance of Socialtext::Async::Wrapper::Worker
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
            scope_guard { Socialtext::Cache->clear };
            my $t = time_scope $worker_name;
            shift; # instance of Socialtext::Async::Wrapper::Worker
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
    $ae_worker = AnyEvent::Worker->new({
        class => 'Socialtext::Async::Wrapper::Worker',
        on_error => sub {
            my ($w,$error,$fatal) = @_;
            warn(($fatal ? "fatal " : "") ."ae-worker error: $error\n");
            undef $ae_worker;
        },
        timeout => 30,
    });
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

    my $err;
    my $cv = AE::cv;
    $ae_worker->do($worker_method_name => $tgt_class, @_, sub {
        $cv->croak("In Worker callback: $@") if $@;
        shift; # callback always passed a ref to the worker
        my $res = \@_;
        $cv->send($res);
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
