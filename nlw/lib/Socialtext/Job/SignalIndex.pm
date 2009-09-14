package Socialtext::Job::SignalIndex;
# @COPYRIGHT@
use Moose;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

sub do_work {
    my $self    = shift;
    my $signal  = $self->signal or return;
    my $indexer = $self->indexer or return;

    $indexer->index_signal($signal);

    $self->completed();
}

__PACKAGE__->meta->make_immutable;
1;
