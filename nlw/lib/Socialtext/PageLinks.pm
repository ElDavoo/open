package Socialtext::PageLinks;
use Moose;
use Socialtext::Paths;
use File::Spec;
use File::Basename qw(basename);
use Socialtext::File;
use Socialtext::Page;
use namespace::clean -except => 'meta';

has 'page' => (
    is => 'ro', isa => 'Socialtext::Page',
    required => 1,
);

has 'hub' => (
    is => 'ro', isa => 'Socialtext::Hub',
    required => 1,
);

has 'links' => (
    is => 'ro', isa => 'ArrayRef[Socialtext::Page]',
    lazy_build => 1,
);

sub _build_links {
    my $self    = shift;
    my $page_id = $self->page->id;
    my $hub = $self->hub;
    return [
        map { Socialtext::Page->new(hub => $hub, id => $_->{to_page_id}) }
        grep { $_->{from_page_id} eq $page_id }
        $self->filesystem_links 
    ];
}

has 'backlinks' => (
    is => 'ro', isa => 'ArrayRef[Socialtext::Page]',
    lazy_build => 1,
);

sub _build_backlinks {
    my $self    = shift;
    my $page_id = $self->page->id;
    my $hub = $self->hub;
    return [
        map { Socialtext::Page->new(hub => $hub, id => $_->{from_page_id}) }
        grep { $_->{to_page_id} eq $page_id }
        $self->filesystem_links 
    ];
}

has 'workspace_directory' => (
    is => 'ro', isa => 'Str',
    lazy_build => 1,
);

sub _build_workspace_directory {
    my $self = shift;
    return File::Spec->catdir(
        Socialtext::Paths::plugin_directory(
            $self->hub->current_workspace->name
        ), 'backlinks',
    );
}

has 'filesystem_links' => (
    is => 'ro', isa => 'ArrayRef[HashRef]',
    lazy_build => 1, auto_deref => 1,
);

sub _build_filesystem_links {
    my $self = shift;

    my $dir = $self->workspace_directory;
    return unless -d $dir;

    # get forward links and backlinks
    my $separator    = '____';
    my $workspace_id = $self->hub->current_workspace->workspace_id;
    my $page_id      = $self->page->id;
    my $glob = "$dir/{${page_id}${separator}*,*${separator}${page_id}}";

    my @links;
    for my $file (glob($glob)) {
        $file = basename($file);
        next if $file =~ /^\.\.?$/;
        my ($from, $to) = split $separator, $file;

        push @links, {
            from_workspace_id => $workspace_id,
            from_page_id      => $from,
            to_workspace_id   => $workspace_id,
            to_page_id        => $to,
        };
    }
    return \@links;
}

has 'db_links' => (
    is => 'ro', isa => 'ArrayRef[HashRef]',
    lazy_build => 1, auto_deref => 1,
);

sub _build_db_links {
    return [];
}

__PACKAGE__->meta->make_immutable;
return 1;
