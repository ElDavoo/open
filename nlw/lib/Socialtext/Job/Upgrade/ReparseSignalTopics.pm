package Socialtext::Job::Upgrade::ReparseSignalTopics;
# @COPYRIGHT@
use Moose;
use Socialtext::Signal;
use Socialtext::Signal::Topic;
use Socialtext::JobCreator;
use Socialtext::SQL qw/sql_execute sql_txn/;
use namespace::clean -except => 'meta';
use Socialtext::File;

extends 'Socialtext::Job';

sub do_work {
    my $self = shift;
    my $hub  = $self->hub or return;

    # Now create jobs to index each signal
    my $sth = sql_execute(
        'SELECT signal_id FROM signal order by signal_id ASC'
    );
    while (my $row = $sth->fetchrow_arrayref) {
        sql_txn {
            my $signal = Socialtext::Signal->Get(signal_id => $row->[0]);

            Socialtext::Signal::Topic->Delete_all_for_signal(
                signal_id => $signal->signal_id,
                'Yes, I really, really mean it.' => 1,
            );

            my (undef, undef, $topics) = Socialtext::Signal->ParseSignalBody(
                $signal->body, $signal->user);

            for my $topic (@$topics) {
                $topic->signal($signal);
                $topic->_insert();
            }
        };
    }
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
