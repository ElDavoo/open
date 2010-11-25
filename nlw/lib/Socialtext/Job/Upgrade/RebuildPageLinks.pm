package Socialtext::Job::Upgrade::RebuildPageLinks;
# @COPYRIGHT@
use Moose;
use Parallel::ForkManager;
use Socialtext::l10n qw/loc loc_lang system_locale/;
use Socialtext::SQL qw/disconnect_dbh get_dbh/;
use Socialtext::PageLinks;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

# This can take a while, especially for super huge workspaces
override 'grab_for'             => sub {3600 * 16};

# Re-parsing all the content for each page can take a long time, so
# we should not allow many of these jobs to run at the same time so that we
# do not stall the ceq queue
sub is_long_running { 1 }

sub do_work {
    my $self = shift;
    my $ws   = $self->workspace or return;
    my $hub  = $self->hub or return;

    return $self->completed unless $ws->real;

    my $ws_name = $ws->name;
    $self->hub->log->info("Rebuilding page links for workspace: $ws_name");

    my @pages = $self->hub->pages->all;
    my $pm = Parallel::ForkManager->new(1);

    # Log any pages that cause core dumps!
    $pm->run_on_finish( sub {
            my $id = $_[2];
            my $core_dump = $_[4];
            $self->hub->log->error("Core dump while parsing $ws_name/$id")
                if $core_dump;
        }
    );

    # Disconnect the DBH so that child processes will create their own
    # connections.
    disconnect_dbh();

    eval {
        for my $page (@pages) {
            # Process each page in a separate process.  This should lessen
            # the impact of core dumps, should they occur.
            $pm->start($page->id) and next;

            my $links = Socialtext::PageLinks->new(hub => $hub, page => $page);
            $links->update;

            $pm->finish;
        }
        $pm->wait_all_children;

        my $dir = Socialtext::PageLinks->WorkspaceDirectory($ws_name);
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

    # Need to explicitly re-connect the DBH after we disconnected it earlier.
    $self->job->dbh(get_dbh());
    $self->completed();
}

__PACKAGE__->meta->make_immutable(inline_constructor => 1);
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
