package Socialtext::Job::SignalIndex;
# @COPYRIGHT@
use Moose;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';
with 'Socialtext::CoalescingJob';

sub do_work {
    my $self    = shift;
    my $indexer = $self->indexer or return;
    my $signal_id = $self->arg->{signal_id};
    my $signal  = $self->signal;

    if ($signal) {
        $indexer->index_signal($signal);
    }
    else {
        $indexer->delete_signal($signal_id);
    }

    $self->completed();
}

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Socialtext::Job::SignalIndex - index a signal.

=head1 SYNOPSIS

    use Socialtext::JobCreator;

    Socialtext::JobCreator->index_signal($signal);

=head1 DESCRIPTION

Schedule a job to be run by TheCeq which will index the signal using Solr.

=cut
