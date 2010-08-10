package Socialtext::Job::Upgrade::IndexOffice2007PageAttachments;
# @COPYRIGHT@
use Moose;
use File::Find::Rule;
use Socialtext::JobCreator;
use Socialtext::Paths;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';
with 'Socialtext::CoalescingJob';

sub do_work {
    my $self = shift;

    my $ws      = $self->workspace;
    my $att_dir = File::Spec->catdir(
        Socialtext::Paths::plugin_directory($ws->name),
        'attachments',
    );

    my $att_list = $self->_office_2007_attachments_under($att_dir);
    my $ws_id    = $ws->workspace_id;
    foreach my $att (@{$att_list}) {
        my ($page_id, $att_id) = ($att =~ m{$att_dir/([^/]+)/([^/]+)/});
        $self->_reindex_attachment($ws_id, $page_id, $att_id);
    }

    $self->completed();
}

sub _office_2007_attachments_under {
    my ($self, $att_dir) = @_;
    # Finding by name is ok; that's how we check for these in ST:F:Stringify
    my @files = File::Find::Rule->file()
        ->name( qr/\.(docx|pptx|xlsx)$/i )
        ->in($att_dir);
    return \@files;
}

sub _reindex_attachment {
    my ($self, $ws_id, $page_id, $att_id) = @_;
    Socialtext::JobCreator->index_attachment_by_ids(
        workspace_id => $ws_id,
        page_id      => $page_id,
        attach_id    => $att_id,
        priority     => 54,
    );
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Socialtext::Job::Upgrade::IndexOffice2007PageAttachments - Index Office 2007 page attachments

=head1 SYNOPSIS

  use Socialtext::JobCreator;

    Socialtext::JobCreator->insert(
        'Socialtext::Job::Upgrade::IndexOffice2007PageAttachments', {
            workspace_id => $workspace_id,
        },
    );

=head1 DESCRIPTION

Finds all Pages in the specified Workspace that have an Office 2007 document
attached to them, and creates jobs to have those attachments indexed.

Up until this point we weren't indexing Office 2007 documents, so there
shouldn't be anything in the search index for them.

=cut
