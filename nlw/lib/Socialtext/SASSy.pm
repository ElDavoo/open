package Socialtext::SASSy;
# @COPYRIGHT@
use Moose;
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

has 'skin_path' => ( is => 'ro', isa => 'Str', lazy_build => 1 );
sub _build_skin_path {
    my $self = shift;
    return join('/', $self->code_base, 'skin', $self->account->skin_name);
}
has 'skin_uri' => ( is => 'ro', isa => 'Str', lazy_build => 1 );
sub _build_skin_uri {
    my $self = shift;
    return join('/', $self->static_path, 'skin', $self->account->skin_name);
}

has 'order_file' => ( is => 'ro', isa => 'Str', lazy_build => 1 );
sub _build_order_file {
    my $self = shift;
    return $self->skin_path . '/css/order.yaml';
}

has 'files' => (
    is => 'ro', isa => 'ArrayRef', lazy_build => 1, auto_deref => 1,
);
sub _build_files {
    my $self = shift;
    return [ glob($self->skin_path . '/css/*') ]
}

has 'dir' => ( is => 'ro', isa => 'Str', lazy_build => 1 );
sub _build_dir {
    my $self = shift;
    my $name = $self->account->name;
    return join('/', 'theme', substr($name, 0, 2), substr($name, 2));
}

has 'cache_dir' => ( is => 'ro', isa => 'Str', lazy_build => 1 );
sub _build_cache_dir {
    my $self = shift;
    return Socialtext::Paths::cache_directory($self->dir);
}

has 'sass_file' => ( is => 'ro', isa => 'Str', lazy_build => 1 );
sub _build_sass_file {
    my $self = shift;
    mkpath $self->cache_dir unless -d $self->cache_dir;
    return $self->cache_dir . "/account.sass";
}

has 'css_file' => ( is => 'ro', isa => 'Str', lazy_build => 1 );
sub _build_css_file {
    my $self = shift;
    mkpath $self->cache_dir unless -d $self->cache_dir;
    return $self->cache_dir . "/account.css";
}

sub protected_uri {
    my $self = shift;
    my $file = shift;
    return join('/', '/nlw', $self->dir, $file);
}

sub needs_update {
    my $self = shift;
    return 1 unless -f $self->css_file;
    if ($self->is_dev_env) {
        my $latest = (sort map { (stat($_))[9] } $self->files)[-1];
        return $latest > (stat($self->css_file))[9];
    }
    return 0;
}

sub render {
    my $self = shift;
    my $theme = $self->account->prefs->all_prefs->{theme};

    $theme->{skin} = '"' . $self->skin_uri . '"';

    my @lines;

    # Variable Expansion
    for my $key (keys %$theme) {
        push @lines, "\$$key: $theme->{$key}\n";
    }
    push @lines, "\@import style.sass\n";

    set_contents($self->sass_file, join('', @lines));

    $Socialtext::System::SILENT_RUN = 1;
    shell_run(
        '/var/lib/gems/1.8/bin/sass',
        '-I', $self->skin_path . '/css', # Add sass files from starfish
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
