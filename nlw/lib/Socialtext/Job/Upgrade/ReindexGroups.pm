package Socialtext::Job::Upgrade::ReindexGroups;
# @COPYRIGHT@
use Moose;
use Socialtext::Groups;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

sub do_work {
    my $self = shift;
    my $ws   = $self->workspace or return;
    my $hub  = $self->hub or return;

    eval { Socialtext::Groups->IndexGroups() };
    $self->hub->log->error($@) if $@;

    $self->completed();
}

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Socialtext::Job::Upgrade::ReindexGroups - Delete groups from Solr & reindex

=head1 SYNOPSIS

    use Socialtext::JobCreator;

    Socialtext::JobCreator->insert(
        'Socialtext::Job::Upgrade::ReindexGroups',
    );

=head1 DESCRIPTION

Schedules a job to be run by TheCeq which will delete all groups from Solr
and then schedule additional jobs to index each group.

=cut
