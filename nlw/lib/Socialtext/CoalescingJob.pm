package Socialtext::CoalescingJob;
# @COPYRIGHT@

use Moose::Role;

requires 'do_work';
requires 'completed';

has '_started_at' => (is => 'rw', isa => 'Int');

before 'do_work' => sub {
    my $self = shift;
    $self->_started_at(time());
};

after 'completed' => sub {
    my $self = shift;

    my $main_job = $self->job;
    my $key  = $main_job->coalesce;
    return unless $key;

    my $class = $main_job->funcname;
    my $client = $main_job->client;
    my @ids;
    while (my $job = $client->find_job_with_coalescing_value($class, $key)) {
        # Avoid a race condition where a job could have _just_ been added.
        # Err on the side of caution: let jobs created in the same second
        # execute later.
        next if $job->insert_time >= $self->_started_at;

        # Otherwise we can skip the extra work!
        $job->completed;
        push @ids, $job->jobid;
    }
    $main_job->arg->{coalesced} = scalar(@ids) if @ids;
};

no Moose::Role;
1;

=head1 NAME

Socialtext::CoalescingJob

=head1 SYNOPSIS

    package MyJob;
    use Moose;
    extends 'Socialtext::Job';
    with 'Socialtext::CoalescingJob';

    sub do_work { ... }

=head1 DESCRIPTION

Causes jobs with matching coalesce values to also be completed if this job is
successful.  Jobs without coalescing keys are skipped.

Only jobs created B<before> this one starts running are considered in order to
prevent a race condition.

=cut
