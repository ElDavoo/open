package Socialtext::Upload;
# @COPYRIGHT@
use Moose;
use Socialtext::Moose::UserAttribute;
use Socialtext::MooseX::Types::Pg;
use Data::UUID;
use Socialtext::SQL qw/:exec sql_txn sql_format_timestamptz/;
use Socialtext::SQL::Builder qw/sql_nextval sql_insert sql_update/;
use Socialtext::JSON qw/json_true json_false/;
use File::Copy qw/copy move/;
use Fatal qw/copy move rename open close unlink/;
use File::Type;
use Try::Tiny;
use namespace::clean -except => 'meta';

our $UPLOAD_DIR = "/tmp";
our $STORAGE_DIR = "/var/www/socialtext/attachments";
warn 'warning: $STORAGE_DIR is still hard-coded';
warn 'warning: need a cron job to sync DB with temp-reaped filesys';
warn 'warning: derive mime_type using File::Type';
#     my $mime = File::Type->new->mime_type($file);

has 'attachment_id' => (is => 'rw', isa => 'Int');
has 'attachment_uuid' => (is => 'rw', isa => 'Str');
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

    my $temp_fh;
    if (my $field = $p{cgi_param}) {
        my $q = $p{cgi};
        my $temp_filename = $q->param($field);
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

        $p{mime_type} = try { File::Type->new->mime_type($temp_filename) };
        $p{mime_type} ||= $info{'content-type'};
        die "no Content-Type for upload" unless $p{mime_type};

        $p{content_length} = -s $temp_fh;
    }

    my $creator = $p{creator};
    my $creator_id = $creator ? $creator->user_id : $p{creator_id};

    my $id = sql_nextval('attachment_id_seq');
    my $uuid = $p{uuid} || $class->NewUUID();

    my $mime_type = $p{mime_type} || 'application/octet-stream';
    my $filename = $p{filename};
    my $is_image = ($mime_type =~ m#image/#) ? 1 : 0;
    my $content_length = $p{content_length} || 0;

    sql_insert(attachment => {
        attachment_uuid => $uuid,
        attachment_id   => $id,
        creator_id      => $creator_id,
        filename        => $filename,
        content_length  => $content_length,
        mime_type       => $mime_type,
        is_image        => $is_image,
        is_temporary    => 1,
    });

    # Moose type constraints could fail, hence the txn wrapper
    my $self = $class->Get(attachment_id => $id);
    if ($temp_fh) {
        copy($temp_fh, $self->temp_filename);
    }
    return $self;
}

sub NewUUID { return Data::UUID->new->create_str() }

sub Get {
    my ($class, %p) = @_;

    my $attachment_id = delete $p{attachment_id};
    my $attachment_uuid = delete $p{attachment_uuid};
    die "need an ID or UUID to retrieve an attachment"
        unless ($attachment_id || $attachment_uuid);

    my $dbh = sql_execute(q{
        SELECT *, created_at AT TIME ZONE 'UTC' || '+0000' AS created_at_utc
        FROM attachment
        WHERE attachment_id = ? OR attachment_uuid = ?},
        $attachment_id, $attachment_uuid);
    my $row = $dbh->fetchrow_hashref();
    $row->{created_at} = delete $row->{created_at_utc};
    return $class->new($row);
}

sub disk_filename {
    my $self = shift;
    return $self->is_temporary ? $self->temp_filename : $self->storage_name;
}

sub temp_filename {
    my $self = shift;
    return "$UPLOAD_DIR/upload-".$self->attachment_uuid;
}

sub storage_name {
    my $self = shift;
    return join('/', $STORAGE_DIR, $self->attachment_uuid);
}

sub created_at_str { sql_format_timestamptz($_[0]->created_at) }

sub to_hash {
    my ($self, $viewer) = shift;
    my %hash = map { $self->$_ } qw(
        attachment_id attachment_uuid filename
        mime_type content_length creator_id
    );
    $hash{created_at} = $self->created_at_str;
    $hash{is_temporary} = $self->is_temporary ? json_true : json_false;
    $hash{is_image} = $self->is_image ? json_true : json_false;

    if ($viewer && $viewer->is_business_admin) {
        my $filename = $self->disk_filename;
        my $stat = [stat $filename];
        my $exists = -f _;
        $hash{physical_status} = {
            filename => $filename,
            'exists' => $exists ? json_true : json_false,
            'stat' => $stat,
        };
    }

    return \%hash;
}

sub purge {
    my $self = shift;
    # missing file is OK
    try { unlink $self->disk_filename };
    sql_execute(q{DELETE FROM attachment WHERE attachment_id = ?},
        $self->attachment_id);
}

sub make_permanent {
    my ($self, %p) = @_;

    return unless $self->is_temporary;

    my $targ = $self->storage_name;
    move($self->temp_filename => $targ.'.tmp');
    sql_execute(q{UPDATE attachment SET is_temp = f
                  WHERE attachment_id = ?}, $self->attachment_id);
    rename($targ.'.tmp' => $targ);
    $self->is_temporary(undef);
}

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
