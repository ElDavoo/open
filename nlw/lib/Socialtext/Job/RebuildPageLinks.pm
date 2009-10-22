package Socialtext::Job::RebuildPageLinks;
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

    loc_lang(system_locale());

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
