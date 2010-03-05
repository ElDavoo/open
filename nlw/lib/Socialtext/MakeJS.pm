package Socialtext::MakeJS;
use strict;
use warnings;
use Socialtext::AppConfig;
use Socialtext::System qw(shell_run);
use Socialtext::JSON qw(encode_json);
use File::Basename qw(dirname);
use JavaScript::Minifier::XS qw(minify);
use File::Slurp qw(slurp write_file);
use Template;
use YAML;
use File::chdir;
use Jemplate;
use Compress::Zlib;
use namespace::clean -except => 'meta';

our $VERBOSE = 0;
my $code_base = Socialtext::AppConfig->code_base;

my @dirs = (
    glob("$code_base/skin/*/javascript/JS.yaml"),
    glob("$code_base/plugin/*/share/javascript/JS.yaml"),
);
my %dirs;
for my $file (@dirs) {
    my ($subdir) = $file =~ m{$code_base/(.*)/JS\.yaml};
    warn "Loading $file\n";
    $dirs{$subdir} = YAML::LoadFile($file);
}

sub CleanAll {
    my ($class) = @_;
    for my $dir (keys %dirs) {
        warn "Cleaning in directory $dir...\n" if $VERBOSE;
        $class->CleanDir($dir);
    }
}

sub BuildAll {
    my ($class) = @_;
    for my $dir (keys %dirs) {
        $class->BuildDir($dir);
    }
}

sub BuildDir {
    my ($class, $dir) = @_;
    for my $target (keys %{$dirs{$dir}}) {
        $class->Build($dir, $target);
    }
}

sub CleanDir {
    my ($class, $dir) = @_;
    local $CWD = "$code_base/$dir";
    warn "Cleaning files in dir $dir...\n" if $VERBOSE;
    my @toclean;
    for my $file (keys %{$dirs{$dir}}) {
        push @toclean, $file;
        push @toclean, "$file.gz" if $dirs{$dir}{$file}{compress};
    }
    unlink @toclean;
}

sub Build {
    my ($class, $dir, $target) = @_;

    local $CWD = "$code_base/$dir";
    my $info = $dirs{$dir}{$target} || return;

    warn "Checking $dir/$target...\n" if $VERBOSE;

    my $parts = $info->{parts} || die "$target has no parts!";

    # Iterate over parts, building as we go
    my @last_modifieds;
    for my $part (@$parts) {
        # Clean the data
        $part = ref $part ? $part : { file => $part };
        $part->{dir} ||= $dir;

        # Check if this is a built file
        if ($part->{file} and $dirs{ $part->{dir} }{ $part->{file} }) {
            $class->Build($part->{dir}, $part->{file});
        }
        push @last_modifieds, $class->_part_last_modified($part);
    }

    # Return if the file is up-to-date
    return if (modified($target) >= (sort @last_modifieds)[-1]);
    warn "Building $dir/$target...\n" if $VERBOSE;
    # Now actually build
    my $text = '';
    for my $part (@$parts) {
        $text .= $class->_part_to_text($part);
        $text .= "\n";
    }

    if (defined $text) {
        write_file($target, $text);
        write_compressed($target, $text) if $info->{compress};
    }
}

sub _part_last_modified {
    my ($class, $part) = @_;
    my @files;
    local $CWD = "$code_base/$part->{dir}";
    push @files, "JS.yaml";
    push @files, glob($part->{file}) if $part->{file};
    push @files, $part->{template} if $part->{template};
    push @files, $part->{config} if $part->{config};
    push @files, $part->{jemplate} if $part->{jemplate};
    push @files, $part->{json} if $part->{json};

    if (my $template = $part->{widget_template}) {
        push @files, 'Widgets.yaml';
        push @files, $template;
        #push @files, $part->{target}; XXX???
    }
    return map { modified($_) } @files;
}

sub _part_to_text {
    my ($class, $part) = @_;
    local $CWD = "$code_base/$part->{dir}";
    if ($part->{file}) {
        return $class->_file_to_text($part);
    }
    if ($part->{template}) {
        return $class->_template_to_text($part);
    }
    elsif ($part->{command}) {
        return $class->_command_to_text($part);
    }
    elsif ($part->{jemplate}) {
        return $class->_jemplate_to_text($part);
    }
    elsif ($part->{widget_template}) {
        return $class->_widget_jemplate_to_text($part);
    }
    elsif ($part->{json}) {
        return $class->_json_to_text($part);
    }
    else {
        die "Don't know how to create part: $part->{dir}";
    }
}

sub _file_to_text {
    my ($class, $part) = @_;
    my $text = '';
    for my $file (glob($part->{file})) {
        $text .= "// BEGIN $part->{file}\n" unless $part->{nocomment};
        $text .= slurp($file);
    }
    return $text;
}

sub _template_to_text {
    my ($class, $part) = @_;

    my $template = $part->{template} || die 'template file required';
    my $config_file = $part->{config} || '';
    die "template $template doesn't exist!" unless -f $template;
    die "$config_file doesn't exist" if $config_file and !-f $config_file;

    # Load template vars
    my $config = $config_file ? YAML::LoadFile($config_file) : {};
    $config->{make_time} = time;

    my $output;
    Template->new->process($template, $config, \$output);
    my $begin = '';
    $begin .= $part->{nocomment} ? '' : "// BEGIN $part->{template}\n";
    return join '', $begin, $output;
}

sub _command_to_text {
    my ($class, $part) = @_;
    $Socialtext::System::SILENT_RUN = !$VERBOSE;
    my $text = '';
    $text .= $part->{nocomment} ? '' : "// BEGIN $part->{command}\n";
    return qx/$part->{command}/;
}

sub _jemplate_to_text {
    my ($class, $part) = @_;
    my $text ='';
    $text .= $part->{nocomment} ? '' : "// BEGIN $part->{jemplate}\n";
    return Jemplate->compile_template_files($part->{jemplate});
}

sub _json_to_text {
    my ($class, $part) = @_;
    my $name = $part->{name} || die "name required";
    my $text = '';
    $text .= $part->{nocomment} ? '' : "// BEGIN $part->{json}\n";
    $text .= "$name = " . encode_json(YAML::LoadFile($part->{json})) . ";";
    return $text;
}

# This is a one off for widgets and should only happen in the wikiwyg skin
sub _widget_jemplate_to_text {
    my ($class, $part) = @_;

    $Socialtext::System::SILENT_RUN = !$VERBOSE;

    my $yaml = YAML::LoadFile('Widgets.yaml');

    my @jemplates;
    if ($part->{all}) {
        for my $widget (@{$yaml->{widgets}}) {
            $class->_render_widget_jemplate(
                yaml => $yaml,
                output => "jemplate/widget_${widget}_edit.html",
                template => $part->{widget_template},
            );
            push @jemplates, "jemplate/widget_${widget}_edit.html";
        }
    }
    elsif ($part->{target}) {
        $class->_render_widget_jemplate(
            yaml => $yaml,
            output => $part->{target},
            template => $part->{widget_template},
        );
        push @jemplates, $part->{target};
    }
    else {
        die "Don't know how to render widget jemplate";
    }

    my $text = '';
    $text .= $part->{nocomment}
        ? '' : "// BEGIN widgets $part->{widget_template}\n";
    $text .= Jemplate->compile_template_files(@jemplates);
    return $text;
}

{
    my $tt2;

    sub _render_widget_jemplate {
        my ($class, %vars) = @_;
        my $yaml_data = delete $vars{yaml} || die;
        my $output_file = $vars{output} || die;
        my $template = $vars{template} || die;
        my $widget_data = $yaml_data->{widget} || die;

        my ($type, $kind) = ('','');
        if ($output_file =~ /^jemplate\/widget_(\w+)_(\w+)\.html$/) {
            ($type, $kind) = ($1, $2);
        }

        $tt2 ||= Template->new({
            START_TAG => '<!',
            END_TAG => '!>',
            INCLUDE_PATH => ['template'],
        });

        my $widget = $widget_data->{$type};
        my @required = defined $widget->{required}
          ? (@{$widget->{required}})
          : defined $widget->{field}
            ? ($widget->{field})
            : ();
        my %required = map {($_, 1)} @required;
        my $data = {
            type => $type,
            data => $yaml_data,
            widget => $widget,
            fields =>
                $widget->{field} ? [$widget->{field}] :
                $widget->{fields} ? $widget->{fields} :
                [],
            pdfields => $widget->{pdfields},
            required => \%required,
            menu_hierarchy => $yaml_data->{menu_hierarchy},
        };

        warn "Generating $output_file\n" if $VERBOSE;
        $tt2->process($template, $data, $output_file)
            || die $tt2->error(), "\n";
    }
}

sub write_compressed {
    my ($target, $text) = @_;

    warn "Minifying $target...\n" if $VERBOSE;
    my $minified = minify($text);

    warn "Gzipping $target...\n" if $VERBOSE;
    my $gzipped = Compress::Zlib::memGzip($minified);

    warn "Writing to $target.gz...\n" if $VERBOSE;
    write_file("$target.gz", $gzipped);
}

sub modified {
    return (stat $_[0])[9] || 0;
}

1;
