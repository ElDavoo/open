package Socialtext::Job::SignalIndex;
# @COPYRIGHT@
use Socialtext::Signal::Topic;
use Socialtext::SQL qw/sql_txn/;
use Socialtext::JSON qw/encode_json/;
use Moose;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';
with 'Socialtext::CoalescingJob', 'Socialtext::IndexingJob';

sub do_work {
    my $self    = shift;
    my $indexer = $self->indexer or return;

    if (my $signal = $self->signal) {
        $self->_rebuild_signal_topics($signal)
            if $self->arg->{rebuild_topics};

        $indexer->index_signal($signal);
    }
    else {
        $indexer->delete_signal($self->arg->{signal_id});
    }

    $self->completed();
}

sub _rebuild_signal_topics {
    my $self   = shift;
    my $signal = shift;

    # also clears the signal_asset table for this signal:
    Socialtext::Signal::Topic->Delete_all_for_signal(
        signal => $signal,
        'Yes, I really, really mean it.' => 1,
    );

    # ignore any errors generating topics.
    my (undef,undef,$topics) = eval {
        # XXX: this is duplicated work from the indexer? it uses
        # render_signal_body which needs to parse it out.
        $signal->ParseSignalBody($signal->body, $signal->user);
    };

    # _insert will also do an insert to the signal_asset table if that topic
    # is also an asset.
    for my $topic (@{$topics||[]}) {
        $topic->signal($signal);
        $topic->_insert();
    }

    # attachments are assets too!
    $_->_insert_asset() for @{$signal->attachments};
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
