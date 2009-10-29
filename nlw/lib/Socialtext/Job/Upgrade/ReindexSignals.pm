package Socialtext::Job::Upgrade::ReindexSignals;
# @COPYRIGHT@
use Moose;
use Socialtext::Signal;
use Socialtext::JobCreator;
use Socialtext::SQL qw/sql_execute/;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

sub do_work {
    my $self = shift;
    my $ws   = $self->workspace or return;
    my $hub  = $self->hub or return;

    eval {
        # First, delete all the signals from Solr.
        my $factory = Socialtext::Search::Solr::Factory->new;
        my $indexer = $factory->create_indexer();
        $indexer->delete_signals();

        # Now create jobs to index each signal
        my $sth = sql_execute(
            'SELECT signal_id FROM signal order by signal_id ASC'
        );
        while (my $row = $sth->fetchrow_arrayref) {
            my $signal = Socialtext::Signal->Get(signal_id => $row->[0]);
            Socialtext::JobCreator->index_signal($signal, priority => 60);
        }
    };
    $self->hub->log->error($@) if $@;

    $self->completed();
}

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Socialtext::Job::Upgrade::ReindexSignals - Delete signals from Solr & reindex

=head1 SYNOPSIS

    use Socialtext::JobCreator;

    Socialtext::JobCreator->insert(
        'Socialtext::Job::Upgrade::ReindexSignals',
    );

=head1 DESCRIPTION

Schedules a job to be run by TheCeq which will delete all signals from Solr
and then schedule additional jobs to index each signal.

=cut
