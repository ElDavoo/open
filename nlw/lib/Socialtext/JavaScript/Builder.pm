package Socialtext::JavaScript::Builder;
# @COPYRIGHT@
use Moose;
use methods;
use Socialtext::System qw(shell_run);
use Socialtext::JSON qw(encode_json);
use Socialtext::Paths;
use JavaScript::Minifier::XS qw(minify);
use Template;
use YAML;
use File::chdir;
use Jemplate;
use FindBin;
use Compress::Zlib;
use File::Temp qw(tempdir);
use File::Path qw(mkpath);
use File::Slurp qw(slurp write_file);
use File::Find qw(find);
use File::Basename qw(basename dirname);
use Clone qw(clone);
use Carp qw(confess);
use Cwd;
use lib dirname(__FILE__)."/../../../plugins/widgets/lib";
use namespace::clean -except => 'meta';

has 'output_directory' => ( is => 'ro', isa => 'Str', lazy_build => 1 );

method _build_output_directory {
    my $dir = Socialtext::Paths::storage_directory('javascript');
    mkpath $dir unless -d $dir;
    return $dir;
}

method target_path($target) {
    return $self->output_directory . '/' . $target
}

method part_directory($part) {
    return $self->output_directory
        if $part->{file} and $self->targets->{$part->{file}};
    my $base = $self->code_base;
    return "$base/javascript/wikiwyg" if $part->{widget_template};
    return "$base/javascript/contrib/shindig" if $part->{shindig_feature};
    return "$base/plugin/$part->{plugin}/share/javascript" if $part->{plugin};
    return "$base/javascript";
}

has 'verbose' => ( is => 'ro', isa => 'Bool' );

has 'code_base' => ( is => 'ro', isa => 'Str', lazy_build => 1 );
sub _build_code_base {
    my $base = eval {
        require Socialtext::AppConfig;
        Socialtext::AppConfig->code_base;
    };
    ($base = $FindBin::Bin) =~ s{dev-bin$}{share} if $@;
    return $base;
}

has 'minify_js' => ( is => 'ro', isa => 'Bool', lazy_build => 1 );
sub _build_minify_js {
    my $minify = eval {
        require Socialtext::AppConfig;
        return Socialtext::AppConfig->minify_javascript eq 'on';
    };
    return $@ ? 1 : $minify
}

has 'targets' => ( is => 'ro', isa => 'HashRef', lazy_build => 1 );
method _build_targets {
    my $code_base = $self->code_base;
    my $data = YAML::LoadFile("$code_base/javascript/JS.yaml");
    $self->expand_collapsed($data);

    my @plugins = glob("$code_base/plugin/*");
    for my $plugin_dir (@plugins) {
        next unless -f "$plugin_dir/share/javascript/JS.yaml";
        (my $plugin = $plugin_dir) =~ s{$code_base/plugin/}{};

        my $yaml = YAML::LoadFile("$plugin_dir/share/javascript/JS.yaml");
        $self->expand_collapsed($yaml);

        for my $key (keys %$yaml) {
            die "Multiple targets for $key!\n" if $data->{$key};
            $data->{$key} = $yaml->{$key};
            $data->{$key}{plugin} = $plugin;
        }
    }

    return $data;
}

method expand_collapsed ($targets) {
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

method clean ($target) {
    my @toclean;
    my @targets = $target ? $target : keys %{$self->targets};
    for my $file (@targets) {
        push @toclean, $file;
        push @toclean, "$file.gz" if $self->targets->{$file}{compress};
    }
    warn "Unlinking $_\n" for @toclean;
    unlink map { $self->target_path($_) } @toclean;
}

method is_built ($target) {
    return -f $self->target_path($target);
}

method is_target ($target) {
    return exists $self->targets->{$target};
}

method build ($target) {
    my @targets = $target ? $target : keys %{$self->targets};
    $self->build_target($_) for @targets;
}

method build_target ($target) {
    $target =~ s/\.gz$//; # built anyway
    local $CWD = $self->code_base;

    my $info = $self->targets->{$target};
    
    unless ($info) {
        if (-f $target) {
            return;
        }
        else {
            confess "Don't know how to build $target";
        }
    }

    my $parts = $info->{parts} || die "$target has no parts!";

    # Iterate over parts, building as we go
    my @last_modifieds;
    for my $part (@$parts) {
        # Clean the data
        $part = ref $part ? $part : { file => $part };
        $part->{plugin} = $info->{plugin} unless exists $part->{plugin};

        # Check if this is a built target
        if ($part->{file} and $self->targets->{$part->{file}}) {
            $self->build_target($part->{file});
        }
        push @last_modifieds, $self->_part_last_modified($part);
    }

    # Recompile the current part if any files in `if_modifieds` has been
    # modified.
    for my $part (@{$info->{if_modifieds}}) {
        $part = ref $part ? $part : { file => $part };
        push @last_modifieds, $self->_part_last_modified($part);
    }

    # Return if the file is up-to-date
    my $target_path = $self->target_path($target);
    return if ($self->modified($target_path) >= (sort @last_modifieds)[-1]);
    warn "Building $target...\n" if $self->verbose;
    # Now actually build
    my @text;
    for my $part (@$parts) {
        my $part_text = $self->_part_to_text($part);
        push @text, $part_text if $part_text;
    }

    if (@text) {
        my $text = join '', map { "$_;\n" } @text;
        $self->write_target($target, $text, $info->{compress});
    }
    else {
        die "Error building $target!\n";
    }
}

method _part_last_modified ($part) {
    my @files;
    local $CWD = $self->part_directory($part);
    push @files, glob($part->{file}) if $part->{file};
    push @files, $part->{template} if $part->{template};
    push @files, $part->{config} if $part->{config};
    push @files, $part->{json} if $part->{json};
    push @files, glob("*/*") if $part->{shindig_feature};

    if ($part->{jemplate} and -f $part->{jemplate}) {
        push @files, $part->{jemplate};
    }
    elsif ($part->{jemplate} and -d $part->{jemplate}) {
        find({
            no_chdir => 1,
            wanted => sub { push @files, $_ unless basename($_) =~ /^\./ },
        }, $part->{jemplate});
    }

    if (my $template = $part->{widget_template}) {
        push @files, 'Widgets.yaml';
        push @files, $template;
    }
    return map { $self->modified($_) } @files;
}

method _part_to_text ($part) {
    local $CWD = $self->part_directory($part);
    if ($part->{file}) {
        return $self->_file_to_text($part);
    }
    if ($part->{template}) {
        return $self->_template_to_text($part);
    }
    elsif ($part->{jemplate_runtime}) {
        return $self->_jemplate_runtime_to_text($part);
    }
    elsif ($part->{command}) {
        return $self->_command_to_text($part);
    }
    elsif ($part->{jemplate}) {
        return $self->_jemplate_to_text($part);
    }
    elsif ($part->{widget_template}) {
        return $self->_widget_jemplate_to_text($part);
    }
    elsif ($part->{json}) {
        return $self->_json_to_text($part);
    }
    elsif ($part->{shindig_feature}) {
        return $self->_shindig_feature_to_text($part);
    }
    else {
        die "Do not know how to create part: $part->{dir}";
    }
}

method _shindig_feature_to_text ($part) {
    require Socialtext::Gadgets::Feature;
    my $feature = Socialtext::Gadgets::Feature->new(
        type => $part->{type},
        name => $part->{shindig_feature},
    );
    my $text = $feature->js || return;
    if ($self->minify_js and $text) {
        warn "Minifying feature $part->{shindig_feature}...\n";
        $text = minify($text);
    }
    return $part->{nocomment} ?
        "// BEGIN Shindig Feature $part->{shindig_feature}\n$text" : $text;
}

method _file_to_text ($part) {
    my $text = '';
    for my $file (glob($part->{file})) {
        $text .= "// BEGIN $part->{file}\n" unless $part->{nocomment};
        $text .= slurp($file);
    }
    return $text;
}

method _template_to_text ($part) {
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

method _command_to_text ($part) {
    $Socialtext::System::SILENT_RUN = !$self->verbose;
    my $text = '';
    $text .= $part->{nocomment} ? '' : "// BEGIN $part->{command}\n";
    return qx/$part->{command}/;
}

method _jemplate_runtime_to_text ($part) {
    my $text = '';
    $text .= $part->{nocomment} ? '' : "// BEGIN Jemplate Runtime\n";
    $text .= Jemplate->runtime_source_code($part->{jquery_runtime});
    return $text;
}

method _jemplate_to_text ($part) {
    my $text ='';
    if (-d $part->{jemplate}) {
        # Traverse the directory, so we can maintain template names like
        # element/something.tt2 rather than just something.tt2
        find({
            no_chdir => 1,
            wanted => sub {
                my $jemplate = $File::Find::name;
                return unless -f $jemplate;
                return if basename($File::Find::name) =~ /^\./;

                # Keep the directory name in the template name when
                # include_paths is set
                (my $name = $jemplate);
                $name =~ s{^$part->{jemplate}/}{} unless $part->{include_paths};

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

method _json_to_text ($part) {
    my $name = $part->{name} || die "name required";
    my $text = '';
    $text .= $part->{nocomment} ? '' : "// BEGIN $part->{json}\n";
    $text .= "$name = " . encode_json(YAML::LoadFile($part->{json})) . ";";
    return $text;
}

# This is a one off for widgets and should only happen in the wikiwyg skin
method _widget_jemplate_to_text ($part) {
    $Socialtext::System::SILENT_RUN = !$self->verbose;

    my $yaml = YAML::LoadFile('Widgets.yaml');
    my $dir = tempdir( CLEANUP => 1 );

    my @jemplates;
    if ($part->{all}) {
        for my $widget (@{$yaml->{widgets}}) {
            $self->_render_widget_jemplate(
                yaml => $yaml,
                output => "$dir/widget_${widget}_edit.html",
                template => $part->{widget_template},
            );
            push @jemplates, "$dir/widget_${widget}_edit.html";
        }
    }
    elsif ($part->{target}) {
        $self->_render_widget_jemplate(
            yaml => $yaml,
            output => "$dir/$part->{target}",
            template => "$part->{widget_template}",
        );
        push @jemplates, "$dir/$part->{target}";
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

    method _render_widget_jemplate(%vars) {
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

        warn "Generating $output_file\n" if $self->verbose;
        $tt2->process($template, $data, $output_file)
            || die $tt2->error(), "\n";
    }
}

method write_target ($target, $text, $compress) {
    my $path = $self->target_path($target);
    write_file($path, $text);
    return unless $compress;

    if ($self->minify_js) {
        warn "Minifying $target...\n" if $self->verbose;
        $text = minify($text);
    }

    # This is pure voodoo, but appears to workaround a FF bug that
    # misidentified gzipped js as E4X -- Needs more investigation.
    $text =~ s!;(/\*\s*\n.*?\*/)!;\n!sg;

    warn "Gzipping $target...\n" if $self->verbose;
    my $gzipped = Compress::Zlib::memGzip($text);

    warn "Writing to $path.gz...\n" if $self->verbose;
    write_file("$path.gz", $gzipped);
}

method modified ($file) { return (stat $file)[9] || 0 }

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);

__END__

=head1 NAME

Socialtext::JavaScript::Builder - Rebuild JavaScript as needed

=head1 SYNOPSIS

  use Socialtext::JavaScript::Builder;
  my $builder = Socialtext::JavaScript::Builder->new

  # Rebuild/clean *all* of the JS
  $builder->clean();
  $builder->build();

  # Rebuild/clean the JS in just one of the JS dirs
  $builder->clean($target);
  $builder->build($target);

=head1 DESCRIPTION

Rebuilds the JavaScript files as needed, including minified and gzipped
versions.

B<Way> faster than doing it via F<Makefile>.

=cut
