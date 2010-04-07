package Socialtext::Job::GroupIndex;
# @COPYRIGHT@
use Moose;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';
with 'Socialtext::CoalescingJob';

sub do_work {
    my $self    = shift;
    my $indexer = $self->indexer or return;

    $indexer->index_group($self->group);

    $self->completed();
}

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Socialtext::Job::PersonIndex - index a person profile.

=head1 SYNOPSIS

    use Socialtext::JobCreator;

    Socialtext::JobCreator->index_person($user);

=head1 DESCRIPTION

Schedule a job to be run by TheCeq which will index the profile using Solr.

=cut
