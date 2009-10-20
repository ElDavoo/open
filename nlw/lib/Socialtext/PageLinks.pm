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
    my $self = shift;
    my $links = [];
    push @$links, $self->_filesystem_links;
    push @$links, $self->_db_links;
    return $links;
}

has 'workspace_directory' => (
    is => 'ro', isa => 'Str',
    lazy_build => 1,
);
sub _build_workspace_directory {
    my $self = shift;
    my $dir = File::Spec->catdir(
        Socialtext::Paths::plugin_directory(
            $self->hub->current_workspace->name
        ), 'backlinks',
    );
    Socialtext::File::ensure_directory($dir) unless -d $dir;
    return $dir;
}

sub _filesystem_links {
    my $self = shift;
    my $separator = '____';
    my @pages;
    my $dir = $self->workspace_directory;
    my $page_id = $self->page->id;
    for my $file (glob("$dir/${page_id}${separator}*")) {
        $file = basename($file);
        next if $file =~ /^\.\.?$/;
        my ($from, $to) = split $separator, $file;
        push @pages, Socialtext::Page->new(hub => $self->hub, id => $to);
    }
    return @pages;
}

sub _db_links {
}

sub backlinked_pages {
    my $self = shift;
}

__PACKAGE__->meta->make_immutable;
return 1;
