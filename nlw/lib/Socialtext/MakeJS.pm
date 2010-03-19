package Socialtext::MakeJS;
use strict;
use warnings;
use Socialtext::AppConfig;
use Socialtext::System qw(shell_run);
use Socialtext::JSON qw(encode_json);
use JavaScript::Minifier::XS qw(minify);
use Template;
use YAML;
use File::chdir;
use Jemplate;
use Compress::Zlib;
use File::Slurp qw(slurp write_file);
use File::Find qw(find);
use File::Basename qw(basename dirname);
use Clone qw(clone);
use Carp qw(confess);
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
    $dirs{$subdir} = YAML::LoadFile($file);
    expand_collapsed($dirs{$subdir});
}

sub expand_collapsed {
    my $targets = shift;

    # Check if a regex matches the target, and expand it
    for my $target (keys %$targets) {
        my $expands = delete $targets->{$target}{expand} || next;
        my $info = delete $targets->{$target};

        for my $expand (@$expands) {
            (my $new_target = $target) =~ s{%}{$expand};
            my $clone = $targets->{$new_target} = clone($info);
            for my $part (@{$clone->{parts}}) {
                if (ref $part) {
                    $_ =~ s{%}{$expand}g for values %$part;
                }
                else {
                    $part =~ s{%}{$expand}g;
                }
            }
        }
    }
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

sub Exists {
    my ($class, $dir, $target) = @_;
    if ($target) {
        $target =~ s/\.gz$//; # built anyway
        return $dirs{$dir}{$target} ? 1 : 0;
    }
    else {
        return $dirs{$dir} ? 1 : 0;
    }
}

sub Build {
    my ($class, $dir, $target) = @_;
    $target =~ s/\.gz$//; # built anyway

    local $CWD = "$code_base/$dir";

    my $info = $dirs{$dir}{$target};
    
    unless ($info) {
        if (-f $target) {
            return;
        }
        else {
            confess "$dir/$target doesn't exist!";
        }
    }

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
    my @text;
    for my $part (@$parts) {
        my $part_text = $class->_part_to_text($part);
        push @text, $part_text if $part_text;
    }

    if (@text) {
        my $text = join '', map { "$_\n" } @text;
        write_file($target, $text);
        write_compressed($target, $text) if $info->{compress};
    }
    else {
        die "Error building $target!\n";
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
    push @files, $part->{json} if $part->{json};
    push @files, glob("$part->{shindig_feature}/*") if $part->{shindig_feature};

    if ($part->{jemplate} and -f $part->{jemplate}) {
        push @files, $part->{jemplate};
    }
    elsif ($part->{jemplate} and -d $part->{jemplate}) {
        find({
            no_chdir => 1,
            wanted => sub { push @files, $File::Find::name },
        }, $part->{jemplate});
    }

    if (my $template = $part->{widget_template}) {
        push @files, 'Widgets.yaml';
        push @files, $template;
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
    elsif ($part->{jemplate_runtime}) {
        return $class->_jemplate_runtime_to_text($part);
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
    elsif ($part->{shindig_feature}) {
        return $class->_shindig_feature_to_text($part);
    }
    else {
        die "Do not know how to create part: $part->{dir}";
    }
}

sub _shindig_feature_to_text {
    my ($class, $part) = @_;
    require Socialtext::Gadgets::Features;
    my $feature = Socialtext::Gadgets::Features->new(
        feature_dir => "$CWD/$part->{feature_dir}",
        type => $part->{type},
    );
    my $text;
    if ($part->{shindig_feature} eq 'default') {
        $text = $feature->default_feature_js();
    }
    else {
        $text = $feature->feature_js($part->{shindig_feature});
    }
    return unless $text;
    return $part->{nocomment} ?
        "// BEGIN Shindig Feature $part->{shindig_feature}\n$text" : $text;
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

sub _jemplate_runtime_to_text {
    my ($class, $part) = @_;
    my $text = '';
    $text .= $part->{nocomment} ? '' : "// BEGIN Jemplate Runtime\n";
    $text .= Jemplate->runtime_source_code($part->{jquery_runtime});
    return $text;
}

sub _jemplate_to_text {
    my ($class, $part) = @_;
    my $text ='';
    if (-d $part->{jemplate}) {
        # Traverse the directory, so we can maintain template names like
        # element/something.tt2 rather than just something.tt2
        warn "Finding in $part->{jemplate}";
        find({
            no_chdir => 1,
            wanted => sub {
                my $jemplate = $File::Find::name;
                return unless -f $jemplate;
                (my $name = $jemplate) =~ s{^$part->{jemplate}/}{};
                $text .= $part->{nocomment} ? '' : "// BEGIN $jemplate\n";
                $text .= Jemplate->compile_template_content(
                    scalar(slurp($jemplate)), $name
                );
            },
        }, $part->{jemplate});
    }
    elsif (-f $part->{jemplate}) {
        $text .= $part->{nocomment} ? '' : "// BEGIN $part->{jemplate}\n";
        $text .= Jemplate->compile_template_files($part->{jemplate});
    }
    else {
        die "Don't know how to compile jemplate: $part->{jemplate}";
    }
    return $text;
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

    unlink @jemplates;
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
