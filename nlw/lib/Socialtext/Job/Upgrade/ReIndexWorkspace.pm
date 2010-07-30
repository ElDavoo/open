package Socialtext::Job::Upgrade::ReIndexWorkspace;
# @COPYRIGHT@
use Moose;
use Socialtext::JobCreator;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

sub do_work {
    my $self = shift;
    my $hub = $self->hub;

    my $solr_indexer = Socialtext::Search::Solr::Factory->create_indexer();
    for my $page_id ( $hub->pages->all_ids() ) {
        my $page = $hub->pages->new_page($page_id);
        next if $page->deleted;
        Socialtext::JobCreator->index_page(
            $page, undef,
            page_job_class => 'Socialtext::Job::PageReIndex',
            attachment_job_class => 'Socialtext::Job::AttachmentReIndex',
            indexers => [ $solr_indexer ],
            priority => -32,
        );
    }

    $self->completed();
}

__PACKAGE__->meta->make_immutable;
1;
=head1 NAME

Socialtext::Job::Upgrade::ReIndexWorkspace - Index workspace stuff again

=head1 SYNOPSIS

  use Socialtext::JobCreator;

    Socialtext::JobCreator->insert(
        'Socialtext::Job::Upgrade::ReIndexWorkspace', {
            workspace_id => $workspace_id,
        },
    );

=head1 DESCRIPTION

Finds all Pages and attachments in the specified Workspace and makes a
PageReIndex or AttachmentReIndex job for them.

=cut
