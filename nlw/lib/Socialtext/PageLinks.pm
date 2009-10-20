package Socialtext::PageLinks;
use Moose;
use Socialtext::Paths;
use File::Spec;
use File::Basename qw(basename);
use Socialtext::File;
use Socialtext::Model::Pages;
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
    is => 'ro', isa => 'ArrayRef',
    lazy_build => 1, auto_deref => 1
);

sub _build_links {
    my $self    = shift;
    my $page_id = $self->page->id;
    return [
        map { $self->_create_page($_->{to_workspace_id}, $_->{to_page_id}) }
        grep { $_->{from_page_id} eq $page_id }
        $self->filesystem_links 
    ];
}

sub _create_page {
    my ($self, $workspace_id, $page_id) = @_;
    my $page = Socialtext::Model::Pages->By_id(
        hub => $self->hub,
        workspace_id => $workspace_id,
        do_not_need_tags => 1,
        no_die => 1,
        page_id => $page_id
    );
    unless ($page) {
        # Incipient page:
        my $old_workspace = $self->hub->current_workspace;
        $self->hub->current_workspace(
            Socialtext::Workspace->new(workspace_id => $workspace_id)
        );
        $page = Socialtext::Page->new(hub => $self->hub, id => $page_id);
        $self->hub->current_workspace($old_workspace);
    }
    return $page;
}

has 'backlinks' => (
    is => 'ro', isa => 'ArrayRef',
    lazy_build => 1, auto_deref => 1
);

sub _build_backlinks {
    my $self    = shift;
    my $page_id = $self->page->id;
    return [
        map { $self->_create_page($_->{from_workspace_id}, $_->{from_page_id}) }
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
