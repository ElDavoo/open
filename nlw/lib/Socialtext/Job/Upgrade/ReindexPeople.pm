package Socialtext::Job::Upgrade::ReindexPeople;
# @COPYRIGHT@
use Moose;
use Socialtext::People::Profile;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

sub do_work {
    my $self = shift;
    my $ws   = $self->workspace or return;
    my $hub  = $self->hub or return;

    eval {
        # First, delete all the people from Solr.
        my $factory = Socialtext::Search::Solr::Factory->new;
        my $indexer = $factory->create_indexer();
        $indexer->delete_people();

        # Now create new jobs for each person.
        Socialtext::People::Profile->IndexPeople();
    };
    $self->hub->log->error($@) if $@;

    $self->completed();
}

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Socialtext::Job::Upgrade::ReindexPeople - Delete people from Solr & reindex

=head1 SYNOPSIS

    use Socialtext::JobCreator;

    Socialtext::JobCreator->insert(
        'Socialtext::Job::Upgrade::ReindexPeople',
    );

=head1 DESCRIPTION

Schedules a job to be run by TheCeq which will delete all people from Solr
and then schedule additional jobs to index each person.

=cut
