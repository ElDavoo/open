package Socialtext::Attachment;
# @COPYRIGHT@
use Moose;
use MooseX::StrictConstructor;
use Carp qw/croak confess/;
use Scalar::Util qw/blessed/;
use Try::Tiny;
use Fcntl qw/LOCK_EX/;

use Socialtext::Upload;
use Socialtext::File ();
use Socialtext::SQL qw/:exec :txn/;
use Socialtext::SQL::Builder qw/sql_insert/;
use Socialtext::String;
use Socialtext::Timer qw/time_scope/;

use namespace::clean -except => 'meta';

my $MAX_WIDTH  = 600;
my $MAX_HEIGHT = 600;

has 'hub' => (
    is => 'ro', isa => 'Socialtext::Hub',
    weak_ref => 1, predicate => 'has_hub'
);

# pseudo-FK into the "page" table. The page may be in the process of being
# created and thus may not "exist" until after this attachment gets stored.
has 'page_id' => (is => 'ro', isa => 'Str', required => 1);
has 'workspace_id' => (is => 'ro', isa => 'Int', required => 1);

# FK into the "attachment" table. Used to build ->upload:
has 'attachment_id' => (is => 'rw', isa => 'Int', writer => '_attachment_id');

# Legacy identifier, date-based:
has 'id' => (is => 'rw', isa => 'Str', writer => '_id',
    default => \&new_id);

has 'deleted' => (is => 'rw', isa => 'Bool',
    reader => 'is_deleted', writer => '_deleted');
*deleted = *is_deleted;

has 'page' => (is => 'ro', isa => 'Object', lazy_build => 1);
has 'workspace' => (is => 'ro', isa => 'Socialtext::Workspace', lazy_build => 1);

has 'upload' => (
    is => 'rw', isa => 'Socialtext::Upload',
    lazy_build => 1,
    handles => [qw(
        attachment_uuid clean_filename content_length created_at
        created_at_str creator creator_id ensure_stored filename is_image
        is_temporary mime_type protected_uri short_name to_string
    )],
    trigger => sub { $_[0]->_attachment_id($_[1]->attachment_id) },
);
*uploaded_by = *creator;

use constant COLUMNS => qw(id workspace_id page_id attachment_id deleted);
use constant COLUMNS_STR => join ', ', COLUMNS;

override 'BUILDARGS' => sub {
    my $class = shift;
    my $p = ref($_[0]) eq 'HASH' ? $_[0] : {@_};
    if (my $hub = $p->{hub}) {
        $p->{workspace} = $hub->current_workspace;
        $p->{workspace_id} = $p->{workspace}->workspace_id;
    }
    return $p;
};

sub _build_page {
    my $self = shift;
    croak "Can't build page: no hub on this Attachment" unless $self->has_hub;
    $self->hub->pages->new_page($self->page_id);
}

sub _build_workspace {
    my $self = shift;
    return Socialtext::Workspace->new(workspace_id => $self->workspace_id);
}

sub _build_upload {
    my $self;
    my $att_id = $self->attachment_id;
    croak "This Attachment hasn't been saved yet" unless $att_id;
    return Socialtext::Upload->Get(attachment_id => $att_id);
}

# legacy ID generator (new stuff should use UUIDs)
my $id_counter = 0;
sub new_id {
    my ($sec, $min, $hour, $mday, $mon, $year) = gmtime(time);
    return sprintf('%4d%02d%02d%02d%02d%02d-%d-%d',
        $year+1900, $mon+1, $mday, $hour, $min, $sec, $id_counter++, $$
    );
}

sub extract {
    my $self = shift;
    my $t = time_scope 'attachment_extract';

    die "TODO: unzip and add these too";
    # TODO: de-duplicate files by doing md5 lookups and multiply-assigning
    # Uploads to attachments.

#     my $filename = join '/',
#         $self->hub->attachments->plugin_directory,
#         $self->page_id,
#         $self->id,
#         $self->db_filename;
# 
#     my $tmpdir = File::Temp::tempdir( CLEANUP => 1 );
# 
#     # Socialtext::ArchiveExtractor uses the extension to figure out how to extract the
#     # archive, so that must be preserved here.
#     my $basename = File::Basename::basename($filename);
#     my $tmparchive = "$tmpdir/$basename";
# 
#     open my $tmpfh, '>', $tmparchive
#         or die "Couldn't open $tmparchive for writing: $!";
#     File::Copy::copy($filename, $tmpfh)
#         or die "Cannot save $basename to $tmparchive: $!";
#     close $tmpfh;
# 
#     my @files = Socialtext::ArchiveExtractor->extract( archive => $tmparchive );
#     # If Socialtext::ArchiveExtractor couldn't extract anything we'll
#     # attach the archive file itself.
#     @files = $tmparchive unless @files;
# 
#     for my $file (@files) {
#         open my $fh, '<', $file or die "Cannot read $file: $!";
# 
#         my $attachment = Socialtext::Attachment->new(
#             hub      => $self->hub,
#             filename => $file,
#             fh       => $fh,
#             creator  => $self->hub->current_user,
#             page_id  => $self->page_id,
#         );
#         $attachment->save($fh);
#         my $creator = $self->hub->current_user;
#         $attachment->store(user => $creator);
#         $attachment->inline( $self->page_id, $creator );
#     }
# 
#     $self->hub->attachments->cache->clear();
#     
#     return;
}


sub dimensions {
    my ($self, $size) = @_;
    $size ||= '';
    return if $size eq 'scaled' and $self->workspace->no_max_image_size;
    return unless $size;
    return [0, 0] if $size eq 'scaled';
    return [100, 0] if $size eq 'small';
    return [300, 0] if $size eq 'medium';
    return [600, 0] if $size eq 'large';
    return [$1 || 0, $2 || 0] if $size =~ /^(\d+)(?:x(\d+))?$/;
}

sub _prepare_to_serve_image {
    my ($self, $flavor) = @_;

    my $original = $self->disk_filename;
    my $target = "$original.$flavor";
    my $size;
    if (-f $target && ($size = -s _)) {
        # "touch" the atime of the file so this can be used for pruning 
        utime time, $self->created_at->epoch, $target;
        return $size;
    }

    $self->ensure_stored();
    my $dimensions = $self->dimensions($flavor);
    (my $dir = $target) =~ s{/[^/]+$}{};

    try {
        # file *must* have a .png suffix for resize() to work
        my $tmp = File::Temp->new(CLEANUP => 1,
            DIR => $dir, TEMPLATE => "resize-XXXXXX", SUFFIX => 'png');
        die "can't create temp file: $!" unless $tmp;

        Socialtext::Image::resize(
            new_width   => $dimensions->[0],
            new_height  => $dimensions->[1],
            max_height  => $MAX_HEIGHT,
            max_width   => $MAX_WIDTH,
            filename    => $original,
            to_filename => "$tmp", # force-stringify the glob
        );
        rename "$tmp" => $target;
        $size = -s $target;
    }
    catch {
        warn "couldn't scale attachment ".$self->attachment_uuid.": $!";
        $size = 0;
    };

    return $size;
}

sub prepare_to_serve {
    my ($self, $flavor, $protected) = @_;
    undef $flavor if $flavor eq 'original';

    my ($uri,$content_length);
    if ($self->is_image && $flavor) {
        ($uri) = $protected
            ? ($self->protected_uri.".$flavor")
            : ($self->download_uri($flavor));
        $content_length = $self->_prepare_to_serve_image($flavor);
    }

    if (!$content_length) {
        $self->ensure_stored();
        $uri = $protected ? $self->protected_uri : $self->download_uri;
        $content_length = $self->content_length;
    }

    return ($uri, $content_length) if wantarray;
    return $uri;
}

sub store {
    my $self = shift;
    my %p = @_;
    $p{user} //= $self->has_hub ? $self->hub->current_user : undef;
    confess('no user given to Socialtext::Attachment->store')
        unless $p{user};

    croak "Can't save an attachment without an associated Upload object"
        unless $self->has_upload;
    croak "Can't store once deleted (calling delete() does a store())"
        if $self->deleted;

    my %args = map { $_ => $self->$_ } COLUMNS;
    $args{deleted} = 0;

    try {
        sql_txn {
            my $guard = $self->upload->make_permanent(actor => $p{user})
                unless $p{temporary};
            sql_insert('page_attachment' => \%args);
        };
    }
    catch {
        croak "store page attachment failed: attachment already exists?"
            if (/primary.key/i);
        die $_;
    };

    if ($p{temporary}) {
        # Don't index the attachment, but make sure it's in the storage area
        # on disk.
        $self->ensure_stored();
        return;
    }

    $self->reindex();
    return;
}

sub reindex {
    my $self = shift;
    require Socialtext::JobCreator;
    Socialtext::JobCreator->index_attachment($self);
    return;
}

sub make_permanent {
    my $self = shift;
    my %p = @_;
    $p{user} //= $self->has_hub ? $self->hub->current_user : undef;
    confess('no user given to Socialtext::Attachment->make_permanent')
        unless $p{user};
    croak "attachment is not temporary!" unless $self->is_temporary;
    my $guard = $self->upload->make_permanent(actor => $p{user});
    $self->reindex();
    return;
}

sub delete {
    my $self = shift;
    my %p = @_;
    $p{user} //= $self->has_hub ? $self->hub->current_user : undef;
    confess('no user given to Socialtext::Attachment->delete')
        unless $p{user};
    confess "can't delete an attachment that isn't saved yet"
        unless $self->has_upload;

    sql_txn {
        sql_execute(q{
            UPDATE page_attachment SET deleted = true WHERE attachment_id = ?
        }, $self->attachment_id);
        local $!;
        $self->upload->delete(actor => $p{user});
    };

    $self->reindex();
    return;
}

sub inline {
    my ($self, $page, $user) = @_;
    $user //= $self->has_hub ? $self->hub->current_user : undef;

    croak "page argument isn't blessed" unless blessed($page);

    $page->metadata->update(user => $user);
    # prepend wafl
    $page->content($self->image_or_file_wafl() . $page->content);
    $page->store(user => $user);
}

sub should_popup {
    my $self = shift;
    my @easy_going_types = (
        qr|^text/|, # especially text/html
        qr|^image/|,
        qr|^video/|,
        # ...any others?   ...any exceptions?
    );
    return not grep { $self->mime_type =~ $_ } @easy_going_types;
}

sub image_or_file_wafl {
    my $self = shift;
    my $filename = $self->filename;

    return $self->is_image
      ? "{image: $filename}\n\n"
      : "{file: $filename}\n\n";
}

my $ExcerptLength = 350;
sub preview_text {
    my $self = shift;
    my $excerpt;
    $self->to_string(\$excerpt);
    $excerpt = substr( $excerpt, 0, $ExcerptLength ) . '...'
        if length $excerpt > $ExcerptLength;
    return $excerpt;
}

sub purge {
    my $self = shift;

    # clean up the index first
    my $ws = $self->workspace;
    my $ws_name = $ws->name;

    my $u = $self->upload;
    sql_txn {
        sql_execute(q{
            DELETE FROM page_attachment
            WHERE workspace_id = ? AND page_id = ? AND attachment_id = ?
        }, $ws->workspace_id, $self->page_id, $u->attachment_id);
        $u->purge(actor => $self->hub->current_user);
    };

    # If solr/kino are slow, we may wish to do this async in a job.
    require Socialtext::Search::AbstractFactory;
    my @indexers = Socialtext::Search::AbstractFactory->GetIndexers($ws_name);
    for my $indexer (@indexers) {
        $indexer->delete_attachment($self->page_id, $self->id);
    }
}

sub download_uri {
    my ($self, $flavor) = @_;
    $flavor ||= 'original'; # can also be 'files'
    my $ws = $self->workspace->name;
    my $filename_uri  = Socialtext::String::uri_escape($self->clean_filename);
    my $uri = "/data/workspaces/$ws/attachments/".
        $self->page->uri.':'.$self->id."/$flavor/$filename_uri";
}

sub download_link {
    my ($self, $flavor) = @_;
    my $uri = $self->download_uri($flavor);
    my $filename_html = Socialtext::String::html_escape($self->filename);
    return qq(<a href="$uri">$filename_html</a>);
}

sub to_hash {
    my $self = shift;
    my $user = $self->creator;
    return +{
        id   => $self->id,
        uuid => $self->attachment_uuid,
        name => $self->filename,
        uri  => $self->download_uri('original'),
        'content-type'   => $self->mime_type,
        'content-length' => $self->content_length,
        date             => $self->created_at_str,
        uploader         => $user->email_address,
        uploader_name    => $user->display_name,
        uploader_id      => $user->user_id,
        'page-id'        => $self->page_id,
    };
}

__PACKAGE__->meta->make_immutable(inline_constructor => 1);
1;
