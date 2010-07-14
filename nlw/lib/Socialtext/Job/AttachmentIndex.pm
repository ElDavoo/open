package Socialtext::Job::AttachmentIndex;
# @COPYRIGHT@
use Moose;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';
with 'Socialtext::CoalescingJob';

sub do_work {
    my $self = shift;
    my $args = $self->arg;
    my $indexer = $self->indexer
        or die "can't create indexer";

    my $page = eval { $self->page };
    # this should be done in the builder for ->page, but just in case:
    unless ($page && $page->active) {
        $self->permanent_failure(
            "No page $args->{page_id} in workspace $args->{workspace_id}\n"
        );
        return;
    }

    my $attachment = Socialtext::Attachment->new(
        hub     => $page->hub,
        id      => $args->{attach_id},
        page_id => $page->id,
    )->load();

    if ($attachment->deleted) {
        $indexer->delete_attachment( $page->id, $attachment->id );
    }
    else {
        $indexer->index_attachment( $page->id, $attachment );
    }

    $self->completed();
}

__PACKAGE__->meta->make_immutable;
1;
