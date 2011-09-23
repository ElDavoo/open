package Socialtext::SASSy;
# @COPYRIGHT@
use Moose;
use methods;
use Socialtext::HTTP ':codes';
use Socialtext::Paths;
use Socialtext::File qw(get_contents set_contents);
use Socialtext::AppConfig;
use Socialtext::TT2::Renderer;
use Socialtext::System qw(shell_run);
use File::Path qw(mkpath);
use File::Basename qw(basename);
use Socialtext::Helpers;
use YAML;
use namespace::clean -except => 'meta';

use constant code_base => Socialtext::AppConfig->code_base;
use constant is_dev_env => Socialtext::AppConfig->is_dev_env;
use constant static_path => Socialtext::Helpers->static_path;

has 'account' => ( is => 'ro', isa => 'Socialtext::Account', required => 1 );
has 'filename' => ( is => 'ro', isa => 'Str', required => 1 );

# style an be: compact, compressed, or expanded.
has 'style' => ( is => 'ro', isa => 'Str', default => 'compressed' );

has 'files' => (
    is => 'ro', isa => 'ArrayRef', lazy_build => 1, auto_deref => 1,
);
method _build_files { return [ glob($self->code_base . '/sass/*') ] }

has 'dir' => ( is => 'ro', isa => 'Str', lazy_build => 1 );
method _build_dir {
    my $name = $self->account->name;
    return join('/', 'theme', substr($name, 0, 2), substr($name, 2));
}

has 'cache_dir' => ( is => 'ro', isa => 'Str', lazy_build => 1 );
method _build_cache_dir {
    return Socialtext::Paths::cache_directory($self->dir);
}

has 'sass_file' => ( is => 'ro', isa => 'Str', lazy_build => 1 );
method _build_sass_file {
    mkpath $self->cache_dir unless -d $self->cache_dir;
    return $self->cache_dir . '/' . $self->filename . '.out.sass';
}

has 'css_file' => ( is => 'ro', isa => 'Str', lazy_build => 1 );
method _build_css_file {
    mkpath $self->cache_dir unless -d $self->cache_dir;
    return $self->cache_dir . '/' . $self->filename . '.out.css';
}

method protected_uri($file) {
    return join('/', '/nlw', $self->dir, $file);
}

method needs_update {
    return 1 unless -f $self->css_file;
    if ($self->is_dev_env) {
        my $latest = (sort map { (stat($_))[9] } $self->files)[-1];
        return $latest > (stat($self->css_file))[9];
    }
    return 0;
}

method render {
    my $theme = $self->account->prefs->all_prefs->{theme};

    $theme->{static} = '"' . $self->static_path . '"';

    my @lines;

    # Variable Expansion
    for my $key (keys %$theme) {
        push @lines, "\$$key: $theme->{$key}\n";
    }
    push @lines, "\@import " . $self->filename . ".sass\n";

    set_contents($self->sass_file, join('', @lines));

    $Socialtext::System::SILENT_RUN = 1;
    shell_run(
        '/opt/ruby/1.8/bin/sass',
        '--compass',
        '-I', $self->code_base . '/sass', # Add sass files from starfish
        '-t', $self->style,
        $self->sass_file,
        $self->css_file,
    );
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

__END__

=head1 NAME

Socialtext::Handler::theme - rebuilds JS as needed in a dev-env

=head1 SYNOPSIS

  # its mapped in automatically in "uri_map.yaml"

=head1 DESCRIPTION

Rebuilds JS as necessary in your dev-env.

=cut
