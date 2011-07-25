package Socialtext::Theme;
use Moose;
use Socialtext::JSON qw(decode_json encode_json);
use Socialtext::SQL qw(sql_singlevalue sql_execute sql_txn);
use Socialtext::File qw(mime_type);
use Socialtext::AppConfig;
use Socialtext::User;
use Socialtext::Upload;
use YAML ();
use namespace::clean -except => 'meta';

sub EnsureRequiredDataIsPresent {
    my $class = shift;
    my $themedir = Socialtext::AppConfig->code_base . '/themes';
    my $json = sql_singlevalue(qq{
        SELECT value
          FROM "System"
         WHERE field = 'themes'
    });

    my $installed_themes = $json ? decode_json($json) : {};
    my $all_themes = YAML::LoadFile("$themedir/themes.yaml");
    my %removed = map { $_ => 1 } keys %$installed_themes;

    for my $theme_name (keys %$all_themes) {
        my $theme = $all_themes->{$theme_name};

        delete $removed{$theme_name};

        $installed_themes->{$theme_name} = 
            $class->_GetThemeData($theme_name => $theme, $themedir);

    }

    delete $installed_themes->{$_} for keys %removed;

    $json = encode_json($installed_themes);
    sql_txn {
        sql_execute(qq{
            DELETE FROM "System" WHERE field = ?
        }, 'themes');
        sql_execute(qq{
            INSERT INTO "System" (field,value) VALUES (?,?)
        }, 'themes', $json);
    };
}

sub _GetThemeData {
    my $class = shift;
    my $name = shift;
    my $data = shift;
    my $themedir = shift;
    my $creator = Socialtext::User->SystemUser;

    for my $field (qw(header_image background_image)) {
        my $filename = delete $data->{$field};
        my $ids = sql_singlevalue(qq{
            SELECT array_accum(attachment_id)
              FROM attachment
             WHERE filename = ?
        }, $filename);

        if (scalar(@$ids) == 1) {
            $data->{$field} = $ids->[0];
            warn "$name theme: using existing attachment for $field\n";
            next;
        }

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

        $data->{$field} = $file->attachment_id;
    }

    return $data;
}

__PACKAGE__->meta->make_immutable;
1;
