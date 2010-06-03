package Socialtext::Upload;
# @COPYRIGHT@
use Moose;
use Socialtext::Moose::UserAttribute;
use Socialtext::MooseX::Types::Pg;
use Data::UUID;
use Socialtext::SQL qw/:exec sql_txn sql_format_timestamptz/;
use Socialtext::SQL::Builder qw/sql_nextval sql_insert sql_update/;
use File::Copy qw/copy move/;
use File::Path qw/make_path/;
use Fatal qw/copy move rename open close unlink/;
use Try::Tiny;
use Moose::Util::TypeConstraints;
use Socialtext::Exceptions qw/no_such_resource_error data_validation_error/;
use Socialtext::File ();
use Socialtext::Log qw/st_log/;
use Socialtext::JSON qw/encode_json/;
use Guard;
use namespace::clean -except => 'meta';

# NOTE: if this gets changed to anything other than /tmp, make sure tmpreaper is
# monitoring that directory.
our $UPLOAD_DIR = "/tmp";
our $STORAGE_DIR = Socialtext::AppConfig->data_root_dir."/attachments";

subtype 'Str.UUID'
    => as 'Str'
    # e.g. dfd6fd31-e518-41ca-ad5a-6e06bc46f1dd
    => where { /^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/ }
    => message { "invalid UUID" };

has 'attachment_id' => (is => 'rw', isa => 'Int');
has 'attachment_uuid' => (is => 'rw', isa => 'Str.UUID');
has 'filename' => (is => 'rw', isa => 'Str');
has 'mime_type' => (is => 'rw', isa => 'Str');
has 'content_length' => (is => 'rw', isa => 'Int');
has 'created_at' => (is => 'rw', isa => 'Pg.DateTime', coerce => 1);
has_user 'creator' => (is => 'rw', st_maybe => 1);
has 'is_image' => (is => 'rw', isa => 'Bool');
has 'is_temporary' => (is => 'rw', isa => 'Bool');

around 'Create' => \&sql_txn;
sub Create {
    my ($class, %p) = @_;

    my $temp_fh = $p{temp_filename};
    if (my $field = $p{cgi_param}) {
        my $q = $p{cgi};
        $temp_fh = $q->upload($field);
        die "no upload field '$field' found \n" unless $temp_fh;
        my $raw_info = $q->uploadInfo($temp_fh);
        my %info = map { lc($_) => $raw_info->{$_} } keys %$raw_info;

        my $cd = $info{'content-disposition'};
        my $real_filename;
        if ($cd =~ /filename="([^"]+)"/) {
            $real_filename = $1;
        }
        die "no filename in Content-Disposition header" unless $real_filename;

        $p{filename} = $real_filename;
    }

    my $creator = $p{creator};
    my $creator_id = $creator ? $creator->user_id : $p{creator_id};

    my $id = sql_nextval('attachment_id_seq');
    my $uuid = $p{uuid} || $class->NewUUID();

    my $filename = $p{filename};
    my $content_length = $p{content_length} || 0;

    sql_insert(attachment => {
        attachment_uuid => $uuid,
        attachment_id   => $id,
        creator_id      => $creator_id,
        filename        => $filename,
        is_temporary    => 1,
        ($p{created_at} ? (created_at => $p{created_at}) : ()),
        # We will update these 2 next fields below
        mime_type       => 'application/octet-stream',
        is_image        => 0,
        content_length  => $content_length,
    });

    # Moose type constraints can cause the create to fail here, hence the txn
    # wrapper.
    my $self = $class->Get(attachment_id => $id);

    my $disk_filename = $self->temp_filename;
    if ($temp_fh) {
        # copy can take fh or filename
        copy($temp_fh, $disk_filename);
    }

    try {
        my $mime_type = Socialtext::File::mime_type($disk_filename);
        my $is_image = ($mime_type =~ m#image/#) ? 1 : 0;
        $content_length = -s $disk_filename;
        sql_execute(q{
            UPDATE attachment
               SET mime_type = ?, is_image = ?, content_length = ?
             WHERE attachment_id = ?
        }, $mime_type, $is_image, $content_length, $self->attachment_id);
        $self->mime_type($mime_type);
        $self->is_image($is_image);
        $self->content_length($content_length);
    }
    catch {
        warn "Could not detect mime_type of " .$self->temp_filename. ": $_\n";
    };

    st_log()->info(join(',', "UPLOAD,CREATE",
        $self->is_image ? 'IMAGE' : 'FILE',
        encode_json({
            'id'         => $self->attachment_id,
            'uuid'       => $self->attachment_uuid,
            'path'       => $self->disk_filename,
            'creator_id' => $self->creator_id,
            'creator'    => $self->creator->username,
            'filename'   => $self->filename,
            'created_at' => $self->created_at_str,
        })));

    return $self;
}

sub NewUUID { return Data::UUID->new->create_str() }

sub Get {
    my ($class, %p) = @_;

    my $attachment_id = delete $p{attachment_id};
    my $attachment_uuid = delete $p{attachment_uuid};
    data_validation_error("need an ID or UUID to retrieve an attachment")
        unless ($attachment_id || $attachment_uuid);

    my $dbh = sql_execute(q{
        SELECT *, created_at AT TIME ZONE 'UTC' || '+0000' AS created_at_utc
        FROM attachment
        WHERE attachment_id = ? OR attachment_uuid = ?},
        $attachment_id, $attachment_uuid);
    my $row = $dbh->fetchrow_hashref();

    no_such_resource_error(
        message => "Uploaded file not found.",
        name => 'Uploaded file'
    ) unless $row;

    $row->{created_at} = delete $row->{created_at_utc};
    return $class->new($row);
}

sub CleanTemps {
    my $class = shift;
    # tmpreaper period is hard-coded to 7d in gen-config and will be
    # deleteing the files themselves.
    my $sth = sql_execute(q{
        DELETE FROM attachment
        WHERE is_temporary
          AND created_at < 'now'::timestamptz - '7 days'::interval
    });
    warn "Cleaned up ".$sth->rows." temp attachment records"
        if ($sth->rows > 0);
}

sub disk_filename {
    my $self = shift;
    return $self->is_temporary ? $self->temp_filename : $self->storage_filename;
}

sub temp_filename {
    my $self = shift;
    return "$UPLOAD_DIR/upload-".$self->attachment_uuid;
}

sub relative_filename {
    my $self = shift;
    my $id = $self->attachment_uuid;
    my $part1 = substr($id,0,2);
    my $part2 = substr($id,2,2);
    my $file  = substr($id,4);
    return join('/', $part1, $part2, $file);
}

sub storage_filename {
    my $self = shift;
    return join('/', $STORAGE_DIR, $self->relative_filename);
}

sub protected_uri {
    my $self = shift;
    return join('/', '/nlw/attachments', $self->relative_filename);
}

sub created_at_str { sql_format_timestamptz($_[0]->created_at) }

sub as_hash {
    my ($self, $viewer) = shift;
    my %hash = map { $_ => $self->$_ } qw(
        attachment_id attachment_uuid filename
        mime_type content_length creator_id
    );
    $hash{created_at} = $self->created_at_str;
    $hash{is_temporary} = $self->is_temporary ? 1 : 0;
    $hash{is_image} = $self->is_image ? 1 : 0;

    if ($viewer && $viewer->is_business_admin) {
        my $filename = $self->disk_filename;
        my $stat = [stat $filename];
        my $exists = -f _;
        $hash{physical_status} = {
            filename => $filename,
            'exists' => $exists ? 1 : 0,
            'stat' => $stat,
        };
    }

    return \%hash;
}

sub purge {
    my ($self, %p) = @_;
    my $actor = $p{actor} || Socialtext::User->SystemUser;

    # missing file is OK
    try { unlink $self->disk_filename };
    sql_execute(q{DELETE FROM attachment WHERE attachment_id = ?},
        $self->attachment_id);

    st_log()->info(join(',', "UPLOAD,DELETE",
        $self->is_image ? 'IMAGE' : 'FILE',
        encode_json({
            'id'       => $self->attachment_id,
            'uuid'     => $self->attachment_uuid,
            'path'     => $self->disk_filename,
            'actor_id' => $actor->user_id,
            'actor'    => $actor->username,
            'filename' => $self->filename,
        })));
}

sub make_permanent {
    my ($self, %p) = @_;

    return unless $self->is_temporary;

    my $src = $self->temp_filename;
    my $targ = $self->storage_filename;

    (my $dir = $targ) =~ s#/[^/]+$##;
    make_path($dir, {mode => 0774});
    move($src => $targ.'.tmp');

    sql_execute(q{
        UPDATE attachment
           SET is_temporary = false
         WHERE attachment_id = ?
    }, $self->attachment_id);
    rename($targ.'.tmp' => $targ);
    $self->is_temporary(undef);

    if ($p{guard}) {
        # move it back unless this gets cancelled
        return guard { 
            move($targ => "$src.tmp");
            rename("$src.tmp" => $src);
            $self->is_temporary(1);
        };
    }
}
after 'make_permanent' => sub {
    my ($self, %p) = @_;
    my $actor = $p{actor} || Socialtext::User->SystemUser;
    st_log()->info(join(',', "UPLOAD,CONSUME",
        $self->is_image ? 'IMAGE' : 'FILE',
        encode_json({
            'id'        => $self->attachment_id,
            'uuid'      => $self->attachment_uuid,
            'path'      => $self->disk_filename,
            'from-path' => $self->temp_filename,
            'actor_id'  => $actor->user_id,
            'actor'     => $actor->username,
            'filename'  => $self->filename,
        })));
};

sub binary_contents {
    my ($self, $ref) = @_;
    my $filename = $self->disk_filename;

    # read file in mmap'd slurp mode:
    local $/;
    open my $fh, "<:mmap", $filename;
    $$ref = <$fh>;

    close $fh;
    return; # no leaking
}

__PACKAGE__->meta->make_immutable;
1;
