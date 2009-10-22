package Socialtext::PageLinks;
# @COPYRIGHT@
use Moose;
use Socialtext::Paths;
use File::Spec;
use File::Basename qw(basename);
use Socialtext::File;
use Socialtext::Model::Pages;
use Socialtext::Timer;
use Socialtext::SQL::Builder qw(sql_insert_many);
use Socialtext::SQL qw(sql_execute);
use namespace::clean -except => 'meta';

=head1 NAME

Socialtext::PageLinks

=head1 SYNOPSIS

my $page_links = Socialtext::PageLinks->new(page => $page);
my @forward_links = $page_links->links;
my @backlinks = $page_links->backlinks;

=head1 DESCRIPTION

Represents all of a page's links and backlinks

=cut

sub WorkspaceDirectory {
    my ($class, $workspace) = @_;
    die "workspace name required" unless $workspace;
    return File::Spec->catdir(
        Socialtext::Paths::plugin_directory($workspace),
        'backlinks',
    );
}

has 'page' => (
    is => 'ro', isa => 'Socialtext::Page::Base',
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
    Socialtext::Timer->Continue('build_links');
    my $page_id = $self->page->id;
    my @links =
        map { $self->_create_page($_->{to_workspace_id}, $_->{to_page_id}) }
        grep { $_->{from_page_id} eq $page_id } $self->db_links,
        $self->filesystem_links;
    Socialtext::Timer->Pause('build_links');
    return \@links;
}

has 'backlinks' => (
    is => 'ro', isa => 'ArrayRef',
    lazy_build => 1, auto_deref => 1
);

sub _build_backlinks {
    my $self    = shift;
    my $page_id = $self->page->id;
    Socialtext::Timer->Continue('build_backlinks');
    my @backlinks =
        map { $self->_create_page($_->{from_workspace_id}, $_->{from_page_id}) }
        grep { $_->{to_page_id} eq $page_id }
        $self->db_links, $self->filesystem_links;
    Socialtext::Timer->Pause('build_backlinks');
    return \@backlinks;
}

sub update {
    my $self = shift;

    Socialtext::Timer->Continue('update_page_links');
    my $workspace_id = $self->hub->current_workspace->workspace_id;
    my $cur_workspace_name = $self->hub->current_workspace->name;
    my $page_id = $self->page->id;
    my $links = $self->page->get_units(
        'wiki' => sub {
            my $page_id = Socialtext::String::title_to_id($_[0]->title);
            return +{ page_id => $page_id, workspace_id => $workspace_id};
        },
        'wafl_phrase' => sub {
            my $unit = shift;
            return unless $unit->method eq 'include';
            $unit->arguments =~ $unit->wafl_reference_parse;
            my ( $workspace_name, $page_title, $qualifier ) = ( $1, $2, $3 );
            my $page_id = Socialtext::String::title_to_id($page_title);
            my $w = Socialtext::Workspace->new(name => $workspace_name);
            return +{
                page_id => $page_id,
                workspace_id => $w ? $w->workspace_id : $workspace_id,
            };
        }
    );

    sql_execute('
        DELETE FROM page_link
         WHERE from_workspace_id = ?
           AND from_page_id = ?
    ', $workspace_id, $page_id);

    my %seen;
    my @cols = qw(from_workspace_id from_page_id to_workspace_id to_page_id);
    if (@$links) {
        my @values = map {
            [ $workspace_id, $page_id, $_->{workspace_id}, $_->{page_id} ]
        } grep { not $seen{ $_->{workspace_id} }{ $_->{page_id} }++ } @$links;
        sql_insert_many('page_link' => \@cols, \@values);
    }
    Socialtext::Timer->Pause('update_page_links');
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

has 'workspace_directory' => (
    is => 'ro', isa => 'Str',
    lazy_build => 1,
);

sub _build_workspace_directory {
    my $self = shift;
    return $self->WorkspaceDirectory($self->hub->current_workspace->name);
}

has 'filesystem_links' => (
    is => 'ro', isa => 'ArrayRef[HashRef]',
    lazy_build => 1, auto_deref => 1,
);

sub _build_filesystem_links {
    my $self = shift;

    my $dir = $self->workspace_directory;
    return [] unless -d $dir;

    Socialtext::Timer->Continue('build_filesystem_links');
    # get forward links and backlinks
    my $separator    = '____';
    my $workspace_id = $self->hub->current_workspace->workspace_id;
    my $page_id      = $self->page->id;
    my $glob = "$dir/{${page_id}${separator}*,*${separator}${page_id}}";

    # Build a hash table of db links in order to eliminate duplicate.
    # This might be slightly inefficient, but only happens while we are moving
    # over from filesystem links to database links.
    my %in_db;
    for my $l ($self->db_links) {
        next unless $l->{from_workspace_id} eq $l->{to_workspace_id};
        if ($l->{to_page_id} eq $page_id) {
            $in_db{ $l->{from_page_id} } = 1;
        }
        elsif ($l->{to_page_id} eq $page_id) {
            $in_db{ $l->{to_page_id} } = 1;
        }
    }

    my @links;
    for my $file (glob($glob)) {
        $file = basename($file);
        next if $file =~ /^\.\.?$/;
        my ($from, $to) = split $separator, $file;
        next if $in_db{$from} or $in_db{$to};

        push @links, {
            from_workspace_id => $workspace_id,
            from_page_id      => $from,
            to_workspace_id   => $workspace_id,
            to_page_id        => $to,
        };
    }
    Socialtext::Timer->Pause('build_filesystem_links');
    return \@links;
}

has 'db_links' => (
    is => 'ro', isa => 'ArrayRef[HashRef]',
    lazy_build => 1, auto_deref => 1,
);

sub _build_db_links {
    my $self         = shift;
    Socialtext::Timer->Continue('build_db_links');
    my $workspace_id = $self->hub->current_workspace->workspace_id;
    my $page_id      = $self->page->id;
    my $sth = sql_execute('
        SELECT * FROM page_link
         WHERE ( from_workspace_id = ? AND from_page_id = ? )
            OR ( to_workspace_id = ? AND to_page_id = ? )
         ORDER BY from_workspace_id, to_workspace_id, from_page_id, to_page_id
    ', ($workspace_id, $page_id) x 2 );
    my $rows = $sth->fetchall_arrayref({});
    Socialtext::Timer->Pause('build_db_links');
    return $rows;
}

__PACKAGE__->meta->make_immutable;
return 1;
