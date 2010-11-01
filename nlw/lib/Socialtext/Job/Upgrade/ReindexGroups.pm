package Socialtext::Job::Upgrade::ReindexGroups;
# @COPYRIGHT@
use Moose;
use Socialtext::Group;
use Socialtext::Log qw/st_log/;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

sub do_work {
    my $self = shift;

    unless ($self->arg && $self->arg->{no_index}) {
        st_log()->info("removing all groups from solr");
        my $factory = Socialtext::Search::Solr::Factory->new;
        $factory->create_indexer()->delete_groups();
    }
    Socialtext::Group->IndexGroups();

    $self->completed();
}

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Socialtext::Job::Upgrade::ReindexGroups - delete and reindex groups in solr

=head1 SYNOPSIS

    use Socialtext::JobCreator;

    Socialtext::JobCreator->insert(
        'Socialtext::Job::Upgrade::ReindexGroups',
    );

=head1 DESCRIPTION

Schedules a job to be run by TheCeq which will delete all groups from Solr
and then schedule additional jobs to index each group.

=cut
