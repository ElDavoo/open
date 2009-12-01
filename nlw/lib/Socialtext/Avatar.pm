package Socialtext::Avatar;
use Moose::Role;

use DBD::Pg qw/:pg_types/;
use File::Temp qw(tempfile);
use Socialtext::Image;
use Socialtext::File;
use Socialtext::Skin;
use Socialtext::SQL qw(:txn :exec get_dbh);
use Socialtext::SQL::Builder qw(sql_insert sql_update);

sub DefaultPhoto {
    my $self_or_class = shift;
    my $size = shift || die 'size required';

    # get the path to the image, on *disk*
    my $skin = Socialtext::Skin->new( name => 'common' );
    my $dir = File::Spec->catfile($skin->skin_path, "images");

    my $default_arg = "default_$size";
    my $file = $self_or_class->$default_arg || die "no $default_arg!";
    my $blob = Socialtext::File::get_contents_binary("$dir/$file");
    return \$blob;
}

my %SIZES = (
    small => {
        width => 27,
        column => 'small_photo_image',
    },
    large => {
        width => 62,
        column => 'photo_image',
    },
);

requires qw(cache table id_column id synonyms default_large default_small);

has 'cache_dir' => (
    is => 'ro', isa => 'Str',
    lazy_build => 1,
);

sub _build_cache_dir {
    my $self = shift;
    my $table = $self->table;
    my $cache_dir = Socialtext::Paths::cache_directory($self->cache);
    Socialtext::File::ensure_directory($cache_dir);
    return $cache_dir;
}

# Blobs:
has 'large' => (
    is => 'rw', isa => 'ScalarRef',
    lazy_build => 1,
);
sub _build_large { $_[0]->_load('large') }

has 'small' => (
    is => 'rw', isa => 'ScalarRef',
    lazy_build => 1,
);
sub _build_small { $_[0]->_load('small') }

sub set {
    my $self = shift;
    my $blob_ref = shift;

    eval {
        for my $size (qw(small large)) {
            my $width = $SIZES{$size}{width} || die "Unknown size: $size";
            my ($fh, $filename) = tempfile;
            print $fh $$blob_ref;
            close $fh or die "Invalid image: $!";

            Socialtext::Image::extract_rectangle(
                image_filename => $filename,
                width => $width,
                height => $width,
            );
            my $contents = Socialtext::File::get_contents_binary($filename);
            $self->$size(\$contents);
        }

        $self->_save_db(small => $self->small, large => $self->large);
        $self->_save_cache(small => $self->small, large => $self->large);
    };
    # check if there were any problems with the image format
    if ($@) {
        return "Animated images are not supported"
            if $@ =~ /Can't resize animated images/;
        warn $@;
        return "Invalid image";
    }
}

sub purge {
    my $self = shift;
    my $id = $self->id;
    my $table = $self->table;
    my $id_column = $self->id_column;

    # Remove from DB
    sql_execute("DELETE FROM $table WHERE $id_column = ?", $self->id);

    # Remove from cache
    my $cache_dir = $self->cache_dir;
    my $lock_fh = Socialtext::File::write_lock("$cache_dir/.lock");
    for my $size (qw(small large)) {
        unlink "$cache_dir/$id-$size.png";
        my @symlinks = map { s#/#\%2f#g; "$cache_dir/$_-$size.png" }
                       $self->synonyms;
        unlink @symlinks;
    }
}


sub _save_db {
    my ($self, %blobs) = @_;
    die "Must call save with both small and large blobs!"
        unless $blobs{small} and $blobs{large};

    my $dbh = get_dbh;

    my $txn = sql_in_transaction();
    sql_begin_work($dbh) unless $txn;
    eval {
        local $dbh->{RaiseError} = 1; # b/c of direct $dbh usage

        my $table = $self->table;
        my $id_column = $self->id_column;

        my $exists = sql_singlevalue(qq{
            SELECT 1 FROM $table WHERE $id_column = ?
        }, $self->id);

        my $sth;
        if ($exists) {
            $sth = $dbh->prepare("
                UPDATE $table
                   SET photo_image = ?,
                       small_photo_image = ?
                 WHERE $id_column = ?
            ");
        }
        else {
            $sth = $dbh->prepare("
                INSERT INTO $table (photo_image, small_photo_image, $id_column)
                VALUES (?,?,?)
            ");
        }
        $sth->bind_param(1, ${$blobs{large}}, {pg_type => PG_BYTEA});
        $sth->bind_param(2, ${$blobs{small}}, {pg_type => PG_BYTEA});
        $sth->bind_param(3, $self->id);
        $sth->execute;

        die "unable to update image" unless ($sth->rows == 1);

        sql_commit($dbh) unless $txn;
    };
    if ($@) {
        sql_rollback($dbh) unless $txn;
        warn $@;
        return "SQL Error";
    }
}

sub _save_cache {
    my ($self, %blobs) = @_;

    my $cache_dir = $self->cache_dir;
    my $id = $self->id;

    my $lock_fh = Socialtext::File::write_lock("$cache_dir/.lock");

    for my $size (keys %blobs) {
        my $file = "$cache_dir/$id-$size.png";
        my $temp = "$file.tmp";
        my @symlinks = map { s#/#\%2f#g; "$cache_dir/$_-$size.png" }
                       $self->synonyms;

        eval {
            Socialtext::File::set_contents_binary($temp, $blobs{$size});
            rename $temp, $file;
            for my $link (@symlinks) {
                unlink $link; # fail = ok
                link $file => $link;
            }
        };
        warn $@ if $@;
    }
}

sub _load {
    my $self = shift;
    my $size = shift;

    my $column = $SIZES{$size}{column} || die "no known column for $size";
    my $table = $self->table;
    my $id_column = $self->id_column;

    my $sth = sql_execute(
        "SELECT $column FROM $table WHERE $id_column = ?", $self->id
    );
    my $blob;
    $sth->bind_columns(\$blob);
    $sth->fetch();
    $sth->finish();

    my $blob_ref = $blob ? \$blob : $self->DefaultPhoto($size);
    $self->_save_cache($size => $blob_ref);
    return $blob_ref;
}

no Moose::Role;
1;
