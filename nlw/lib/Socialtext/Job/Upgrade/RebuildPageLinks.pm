package Socialtext::Job::Upgrade::RebuildPageLinks;
# @COPYRIGHT@
use Moose;
use Socialtext::l10n qw/loc loc_lang system_locale/;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

# Re-parsing all the content for each page can take a long time, so
# we should not allow many of these jobs to run at the same time so that we
# do not stall the ceq queue
sub is_long_running { 1 }

sub do_work {
    my $self = shift;
    my $ws   = $self->workspace or return;
    my $hub  = $self->hub or return;

    return $self->completed unless $ws->real;

    $self->hub->log->info("Rebuilding page links for workspace: " . $ws->name);

    my @pages = $self->hub->pages->all;
    eval {
        for my $page (@pages) {
            my $links = Socialtext::PageLinks->new(hub => $hub, page => $page);
            $links->update;
        }
        my $dir = Socialtext::PageLinks->WorkspaceDirectory($ws->name);
        if ($dir and -d $dir) {
            for my $file (glob("$dir/*"), "$dir/.initialized") {
                next unless -f $file;
                unlink $file
                    or $self->hub->log->error(
                        "Could not unlink $file during backlink cleanup: $!");
            }
            rmdir $dir or $self->hub->log->error(
                        "Could not rmdir $dir during backlink cleanup: $!");
        }
    };
    $self->hub->log->error($@) if $@;
    $self->completed();
}

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Socialtext::Job::Upgrade::RebuildPageLinks - Rebuild a workspace's page links

=head1 SYNOPSIS

    use Socialtext::JobCreator;

    Socialtext::JobCreator->insert(
        'Socialtext::Job::Upgrade::RebuildPageLinks',
        {
            workspace_id => 1,
        },
    );

=head1 DESCRIPTION

Schedule a job to be run by TheCeq which will rebuild all of a workspace's
links (including backlinks). The legacy filesystem based links are unlinked
after all links have been updated or added to the database.

=cut
