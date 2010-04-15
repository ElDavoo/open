package Socialtext::Async::WorkQueue;
# @COPYRIGHT@
use Moose;
use MooseX::StrictConstructor;
use Coro;
use AnyEvent;
use Coro::AnyEvent;
use Guard;
use namespace::clean -except => 'meta';

=head1 NAME

Socialtext::Async::WorkQueue

=head1 SYNOPSIS

    use Socialtext::Async::WorkQueue;
    my $q = Socialtext::Async::WorkQueue->new(
        name => 'dispatch',
        cb => {
            my ($arg1, $arg2) = @_;
        }
    );
    $q->enqueue(['one','two']);
    $q->shutdown();

=head1 DESCRIPTION

An infinite length work queue.  Avoids the inherent memory leaks in
C<Coro::Channel> by using a linked-list rather than a perl array.

Enqueued tasks are worked on in a C<Coro> thread (one thread per work queue),
cede-ing after each job completes.

=head1 CONSTRUCTOR

=over 4

=item cb

A CodeRef to run for each job.

=item name

The name of this queue (defaults to 'work').

=item after_shutdown

An optional CodeRef to call once all pending jobs have been processed after
the queue has been shut down.  Handy for chaining condvars during a
non-blocking shutdown:

    my $cv = AE::cv;
    my $q = Socialtext::Async::WorkQueue->new(
        ...
        after_shutdown => sub {
            $cv->end;
        }
    );
    $cv->begin;
    ...
    $q->shutdown_nowait();
    $cv->recv;

=back

=cut

has 'cb' => (is => 'ro', isa => 'CodeRef', required => 1);
has 'name' => (is => 'ro', isa => 'Str', required => 1, default => 'work');

# below attributes are "protected"

has 'runner' => (is => 'rw', isa => 'Object', predicate => 'has_runner');
has 'cv' => (is => 'rw', isa => 'Object', writer => '_cv');

has 'is_waiting' => (is => 'rw', isa => 'Bool', default => undef);
has 'is_shutdown' => (is => 'rw', isa => 'Bool', default => undef);

has 'after_shutdown' => (is => 'ro', isa => 'CodeRef', clearer => 'clear_after_shutdown');

for my $end (qw(head tail)) {
    has "$end" => (
        is => 'rw', isa => 'Maybe[ArrayRef]',
        default => undef,
    );
}

sub BUILD {
    my $self = shift;
    my $cv;
    if (my $cb = $self->after_shutdown) {
        $cv = AnyEvent->condvar(cb => $cb);
        $self->clear_after_shutdown;
    }
    else {
        $cv = AE::cv();
    }
    $self->_cv($cv);
    $self->cv->begin; # match in shutdown
}

=head1 METHODS

=over 4

=item enqueue(['job', 'args'])

Enqueue a job, which must be an array-ref.  The contents of the array-ref are
passed in to the C<cb> registered during construction via C<@_>.

=cut

sub enqueue {
    my $self = shift;
    my $args = shift;

    if ($self->is_shutdown) {
        Carp::cluck "attempt to enqueue job to ".$self->name." queue after shutdown\n";
        return;
    }

    my $job = [$args,undef];

    if (my $tail = $self->tail) {
        # add to end of queue if anything is waiting
        $tail->[1] = $job;
        $self->tail($job);
    }
    else {
        $self->head($job);
        $self->tail($job);
    }

    # start a runner since this is the first job
    $self->_start unless $self->has_runner;
    $self->_ready;

    return 1;
}

=item drop_pending()

Drop the reference to all pending jobs.  If a job is currently in progress it
will B<NOT> be cancelled.

=cut

sub drop_pending {
    my $self = shift;
    if (my $head = $self->head) {
        $head->[1] = undef; # detach head
    }
    $self->head(undef);
    $self->tail(undef);
}

sub _start {
    my $self = shift;
    $self->cv->begin;
    $self->runner(async {
        $Coro::current->{desc} = $self->name." queue runner";
        scope_guard { $self->cv->end };
        while (1) {
            $self->_run(); # returns when no more work
            return if $self->is_shutdown;

            $self->is_waiting(1);
            schedule;  # block until someone calls $self->runner->ready
            return if $self->is_shutdown;
        }
    });
}

sub _run {
    my $self = shift;

    scope_guard {
        $self->head(undef);
        $self->tail(undef);
    };

    while (my $head = $self->head) {
        eval { $self->cb->(@{$head->[0]}) };
        warn "Error processing queue ".$self->name.": $@" if $@;

        # shift next onto head and cede if more work
        $head = $head->[1];
        $self->head($head);
        cede if $head;
    }
}

sub _ready {
    my $self = shift;
    if ($self->is_waiting) {
        $self->is_waiting(undef);
        if ($self->has_runner) {
            $self->runner->ready unless $self->runner == $Coro::current;
        }
    }
}

=item shutdown()

=item shutdown(5.0)

Block the current thread and Wait for all jobs to complete.  Prevents new jobs
from being enqueued.

The optional argument is a timeout to wait for jobs to complete, in seconds.
Otherwise, C<shutdown()> will wait forever.  If a timeout occurs, the
exception "timeout while waiting for queue to flush" is thrown..

After the last job has finished, the C<after_shutdown> callback will be called
before C<shutdown()> returns (if present).  If the timeout exception is
thrown, C<after_shutdown> will not be called.

=cut

sub shutdown {
    my $self = shift;
    my $timeout = shift;
    return if $self->is_shutdown;

    if ($self->has_runner) {
        die "can't shutdown queue synchronously from the runner;".
            "use async {} to start a thread?"
            if ($self->runner == $Coro::current);
    }

    $self->is_shutdown(1);
    $self->_ready;

    my $t;
    if ($timeout) {
        $t = AE::timer $timeout, 0, sub {
            $self->cv->croak("timeout while waiting for queue to flush");
        };
    }
    $self->cv->end;
    $self->cv->recv;
}

=item shutdown_nowait()

Mark the queue as shut-down (preventing new jobs from being scheduled) and
return immediately.

After the last job has finished, the C<after_shutdown> callback will be called
asynchronously (if present).

=cut

sub shutdown_nowait {
    my $self = shift;
    return if $self->is_shutdown;
    $self->cv->end;
    $self->is_shutdown(1);
    $self->_ready;
}

__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 AUTHOR

Jeremy Stashewsky C<jeremy.stashewsky@socialtext.com>

=head1 COPYRIGHT

Copyright (c) 2010 Socialtext Inc.  All rights reserved.

=cut
