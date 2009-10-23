package Socialtext::Job::Upgrade::RebuildPageLinks;
# @COPYRIGHT@
use Moose;
use Socialtext::l10n qw/loc loc_lang system_locale/;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

sub do_work {
    my $self = shift;
    my $ws   = $self->workspace or return;
    my $hub  = $self->hub or return;

    return $self->completed unless $ws->real;

    $self->hub->log->info("Rebuilding page links for workspace: " . $ws->name);

    my @pages = $self->hub->pages->all;
    return $self->completed unless @pages;
    eval {
        for my $page (@pages) {
            my $links = Socialtext::PageLinks->new(hub => $hub, page => $page);
            $links->update;
        }
        my $dir = Socialtext::PageLinks->WorkspaceDirectory($ws->name);
        if ($dir and -d $dir) {
            unlink glob("$dir/*") or die "Can't rm * in $dir/: $!";
            unlink "$dir/.initialized" or die "Can't rm $dir/.initialized: $!";
            rmdir $dir or die "Can't rmdir $dir: $!";
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
