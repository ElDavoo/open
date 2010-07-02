package Socialtext::Job::PageIndex;
# @COPYRIGHT@
use Moose;
use Socialtext::PageLinks;
use Socialtext::Log qw/st_log/;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';
with 'Socialtext::CoalescingJob';

sub do_work {
    my $self    = shift;
    my $page    = $self->page or return;
    my $indexer = $self->indexer or return;

    $indexer->index_page($page->id);

    # If this page was just created (only 1 revision) or deleted, then
    # we should clear out any relevant wikitext cache entries
    if ($page->revision_count == 1 or $page->deleted) {
        $self->unlink_cached_wikitext_linkers;
    }

    $self->completed();
}

sub unlink_cached_wikitext_linkers {
    my $self = shift;

    eval {
        my $links = Socialtext::PageLinks->new(
            page => $self->page,
            hub  => $self->hub,
        );
        for my $page (@{ $links->backlinks }) {
            $page->delete_cached_html;
        }
    };
    if ($@) {
        st_log->info("Error cleaning wikitext cache: $@");
    }
}

__PACKAGE__->meta->make_immutable;
1;
