package Socialtext::Theme;
use Moose;
use Socialtext::JSON qw(decode_json encode_json);
use Socialtext::SQL qw(sql_singlevalue sql_execute sql_txn);
use Socialtext::SQL::Builder qw(sql_insert sql_update sql_nextval);
use Socialtext::File qw(mime_type);
use Socialtext::AppConfig;
use Socialtext::User;
use Socialtext::Upload;
use YAML ();
use namespace::clean -except => 'meta';

my @COLUMNS = qw( theme_id name header_color header_image_id
    header_image_tiling header_image_position background_color
    background_image_id background_image_tiling background_image_position
    primary_color secondary_color tertiary_color header_font body_font
    is_default
);

my @UPLOADS = qw(header_image background_image);

has $_ => (is=>'ro', isa=>'Str', required=>1) for @COLUMNS;
has $_ => (is=>'ro', isa=>'Socialtext::Upload', lazy_build=>1) for @UPLOADS;

sub _build_header_image {
    my $self = shift;
    return Socialtext::Upload->Get(attachment_id => $self->header_image_id);
}

sub _build_background_image {
    my $self = shift;
    return Socialtext::Upload->new(attachment_id => $self->background_image_id);
}

sub as_hash {
    my $self = shift;
    my $params = (@_ == 1) ? shift : {@_};

    my %as_hash = map { $_ => $self->$_ } @COLUMNS;

    if (!$params->{set} || $params->{set} ne 'minimal') {
        my $header = $self->header_image;
        $as_hash{header_image_url} = $self->_attachment_url($header);
        $as_hash{header_image_filename} = $header->filename;
        $as_hash{header_image_mime_type} = $header->mime_type;

        my $background = $self->background_image;
        $as_hash{background_image_url} = $self->_attachment_url($background);
        $as_hash{background_image_filename} = $background->filename;
        $as_hash{background_image_mime_type} = $background->mime_type;
    }

    return \%as_hash;
}

# Now you need to make this handler and model SignalAttachment -->
sub _attachment_url {
    my ($self, $image) = @_;
    my $name = $self->name;
    return "/data/theme/$name/attachements/" . $image->attachment_id;
}

sub All {
    my $class = shift;
    return [
        map { $class->new(%$_) } @{$class->_AllThemes()}
    ];
}

sub EnsureRequiredDataIsPresent {
    my $class = shift;
    my $themedir = Socialtext::AppConfig->code_base . '/themes';

    my $installed = { map { $_->{name} => $_ } @{$class->_AllThemes()} };
    my $all = YAML::LoadFile("$themedir/themes.yaml");

    for my $name (keys %$all) {
        my $theme = $all->{$name};
        $theme->{name} = $name;

        if (my $existing = $installed->{$name}) {
            die "no theme_id for installed theme ($name)?\n"
                unless $installed->{$name}{theme_id};

            $class->Update(%$existing, %$theme);
        }
        else {
            $class->Create($theme);
        }
    }
}

sub Update {
    my $class = shift;
    my $params = (@_ == 1) ? shift : {@_};

    die "no theme_id for installed theme ($params->{name})\n"
        unless $params->{theme_id};
    my $to_update = $class->_CleanParams($params);

    sql_update(theme => $to_update, 'theme_id');
    return $class->new(%$to_update);
}

sub Load {
    my $class = shift;
    my $field = shift;
    my $value = shift;

    die "must use a unique identifier"
        unless grep { $_ eq $field } qw(theme_id name);

    my $sth = sql_execute(qq{
        SELECT }. join(',', @COLUMNS) .qq{
          FROM theme
         WHERE $field = ?
    }, $value);

    my $rows = $sth->fetchall_arrayref({});

    return scalar(@$rows)
        ? $class->new(%{$rows->[0]})
        : undef;
}

sub Default {
    my $class = shift;

    my $sth = sql_execute(qq{
        SELECT }. join(',', @COLUMNS) .qq{
          FROM theme
         WHERE is_default IS true
    });

    my $rows = $sth->fetchall_arrayref({});

    die "cannot determine default theme" unless scalar(@$rows) == 1;

    return $class->new(%{$rows->[0]})
}

sub Create {
    my $class = shift;
    my $params = (@_ == 1) ? shift : {@_};

    $params->{theme_id} ||= sql_nextval('theme_theme_id');
    my $to_insert = $class->_CleanParams($params);

    sql_insert(theme => $to_insert);

    return $class->new(%$to_insert);
}

sub _CleanParams {
    my $class = shift;
    my $params = shift;

    $class->_CreateAttachmentsIfNeeded($params);
    return +{ map { $_ => $params->{$_} } @COLUMNS };

}

sub _AllThemes {
    my $class = shift;

    my $sth = sql_execute(qq{
        SELECT }. join(', ', @COLUMNS) .qq{
          FROM theme
    });

    return $sth->fetchall_arrayref({}) || [];
}

sub _CreateAttachmentsIfNeeded {
    my $class = shift;
    my $params = shift;

    my $themedir = Socialtext::AppConfig->code_base . '/themes';
    my $creator = Socialtext::User->SystemUser;

    # Don't worry about breaking links to old upload objects, they'll get
    # auto-cleaned.
    for my $temp_field (qw(header_image background_image)) {
        my $filename = delete $params->{$temp_field};
        next unless $filename;

        my $db_field = $temp_field . "_id";

        my @parts = split(/\./, $filename);
        my $mime_guess = 'image/'. $parts[-1];

        my $tempfile = "$themedir/$filename";
        my $file = Socialtext::Upload->Create(
            creator => $creator,
            temp_filename => $tempfile,
            filename => $filename,
            mime_type => mime_type($tempfile, $filename, $mime_guess),
        );
        $file->make_permanent(actor => $creator); 

        $params->{$db_field} = $file->attachment_id;
    }
}

__PACKAGE__->meta->make_immutable;
1;
