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
my %files;
for my $file (glob("$code_base/skin/*/javascript/Deps.yaml")) {
    my ($plugin) = $file =~ m{/skin/([^/]+)/javascript/};
    $files{$plugin} = YAML::LoadFile($file);
}

sub CleanAllSkins {
    my ($class) = @_;
    for my $skin (keys %files) {
        warn "Cleaning skin $skin...\n" if $VERBOSE;
        $class->CleanSkin($skin);
    }
}

sub BuildAllSkins {
    my ($class) = @_;
    for my $skin (keys %files) {
        warn "Building skin $skin...\n" if $VERBOSE;
        $class->BuildSkin($skin);
    }
}

sub BuildSkin {
    my ($class, $skin) = @_;
    for my $target (keys %{$files{$skin}}) {
        warn "Building $target...\n" if $VERBOSE;
        $class->Build($skin, $target);
    }
}

sub CleanSkin {
    my ($class, $skin) = @_;
    local $CWD = "$code_base/skin/$skin/javascript";
    warn "Cleaning files in skin $skin...\n" if $VERBOSE;
    unlink keys %{$files{$skin}};
}

sub modified {
    return (stat $_[0])[9] || 0;
}

sub _build_from_template {
    my ($class, $info) = @_;

    my $template = $info->{template} || die 'template file required';
    my $config_file = $info->{config} || '';
    die "template $template doesn't exist!" unless -f $template;
    die "$config_file doesn't exist" if $config_file and !-f $config_file;

    my $last_build = modified($info->{target});
    my $uptodate = 1
        if $last_build >= modified($template)
       and (!$config_file or $last_build >= modified($config_file));

    if ($uptodate) {
        return;
    }

    # Load template vars
    my $config = $config_file ? YAML::LoadFile($config_file) : {};
    $config->{make_time} = time;

    warn "Writing to $info->{target}...\n" if $VERBOSE;
    my $output;
    Template->new->process($template, $config, \$output);
    return $output;
}

sub _build_from_command {
    my ($class, $info) = @_;
    if (-f $info->{target}) {
        return;
    }
    warn "Writing to $info->{target}...\n" if $VERBOSE;
    $Socialtext::System::SILENT_RUN = !$VERBOSE;
    shell_run "$info->{command} > $info->{target}";
}

sub _build_from_jemplates {
    my ($class, $info) = @_;
    my $jemplates = $info->{jemplates};
    my $latest = (sort map { modified($_) } @$jemplates)[-1];
    my $last_build = modified($info->{target});
    return unless $latest > $last_build;
    warn "Writing to $info->{target} from jemplates...\n" if $VERBOSE;
    return Jemplate->compile_template_files(@$jemplates);
}

# This is a one off for widgets and should only happen in the wikiwyg skin
sub _build_from_widget_jemplates {
    my ($class, $info) = @_;

    my $items = $info->{widget_jemplates} || die 'no widget_jemplates';;

    my @files = ('Widgets.yaml', map { "template/$_->{template}" } @$items);
    my $latest = (map { modified($_) } @files)[-1];
    return unless $latest > modified($info->{target});

    warn "Writing to $info->{target} from widget jemplates...\n" if $VERBOSE;

    $Socialtext::System::SILENT_RUN = !$VERBOSE;

    my $yaml = YAML::LoadFile('Widgets.yaml');

    my @jemplates;
    for my $item (@$items) {
        if ($item->{all}) {
            for my $widget (@{$yaml->{widgets}}) {
                $class->_render_widget_jemplate(
                    yaml => $yaml,
                    output => "jemplate/widget_${widget}_edit.html",
                    template => $item->{template},
                );
                push @jemplates, "jemplate/widget_${widget}_edit.html";
            }
        }
        else {
            $class->_render_widget_jemplate(
                yaml => $yaml,
                output => $item->{target},
                template => $item->{template},
            );
            push @jemplates, $item->{target};
        }
    }

    return Jemplate->compile_template_files(@jemplates );
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

sub _build_lightbox {
    my ($class, $info) = @_;
    my $lb = $info->{lightbox};
    my $tt2 = "lightbox/$lb.tt2";
    my $js = "lightbox/$lb.js";
    die "$js doesn't exist\n" unless -f $js;
    die "$tt2 doesn't exist\n" unless -f $tt2;

    my $last_build = modified($info->{target});
    return
        if $last_build >= modified($tt2)
            and $last_build >= modified($js)
            and $last_build >= modified('st-lightbox.js');

    warn "Writing to lightbox: $info->{lightbox}\n";
    return join "\n",
        Jemplate->compile_template_files($tt2);
        "// BEGIN st-lightbox.js",
        slurp('st-lightbox.js'), 
        "// BEGIN $js",
        slurp($js);
}

sub _build_json {
    my ($class, $info) = @_;
    my $yaml = $info->{json};
    my $name = $info->{name} || die "name required";

    my $last_build = modified($info->{target});
    return unless modified($yaml) >  $last_build;

    return "$name = " . encode_json(YAML::LoadFile($yaml)) . ";";
}

sub _build_from_files {
    my ($class, $info) = @_;

    # Build a list of files to include, building prereqs as they come up
    my @globs;
    for my $file (@{$info->{files}}) {
        my ($src_skin, $src_file);
        if (ref $file) {
            # Build prereq
            $src_skin = $file->{skin} || $info->{skin};
            $src_file = $file->{target};
        }
        else {
            $src_skin = $info->{skin};
            $src_file = $file;
        }

        # Check if this is a build file
        if ($files{$src_skin}{$src_file}) {
            $class->Build($src_skin, $src_file);
        }
        
        my $path = $info->{skin} eq $src_skin
            ? $src_file :  "../../$src_skin/javascript/$src_file";

        push @globs, $path;
    }

    # Check if we need to build
    my @files = glob(join(' ', @globs));
    my $latest = (sort map { modified($_) } @files)[-1];
    my $last_build = modified($info->{target});

    if ($last_build < $latest) {
        warn "Writing to $info->{target}...\n" if $VERBOSE;
        # Now actually build
        my $all = '';
        for my $file (@files) {
            $all .= "// BEGIN $file\n" unless $info->{nocomment};
            $all .= slurp($file);
            $all .= "\n";
        }
        return $all;
    }
    return;
}

sub Build {
    my ($class, $skin, $target) = @_;

    local $CWD = "$code_base/skin/$skin/javascript";
    my $info = $files{$skin}{$target} || return;

    warn "Starting $skin/$target...\n" if $VERBOSE;

    $info->{target} = $target;
    $info->{skin} ||= $skin;

    my $text;
    if ($info->{template}) {
        $text = $class->_build_from_template($info);
    }
    elsif ($info->{command}) {
        $text = $class->_build_from_command($info);
    }
    elsif ($info->{jemplates}) {
        $text = $class->_build_from_jemplates($info);
    }
    elsif ($info->{widget_jemplates}) {
        $text = $class->_build_from_widget_jemplates($info);
    }
    elsif ($info->{json}) {
        $text = $class->_build_json($info);
    }
    elsif ($info->{lightbox}) {
        $text = $class->_build_lightbox($info);
    }
    elsif ($info->{files}) {
        $text = $class->_build_from_files($info);
    }
    else {
        warn "Don't know how to build $target!\n";
    }

    if (defined $text) {
        write_file($target, $text);
        write_compressed($target, $text) if $info->{compress};
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

1;
