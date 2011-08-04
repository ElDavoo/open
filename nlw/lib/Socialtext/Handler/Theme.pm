package Socialtext::Handler::Theme;
# @COPYRIGHT@
use Moose;
use Socialtext::HTTP ':codes';
use Socialtext::Paths;
use Socialtext::File qw(get_contents set_contents);
use Socialtext::AppConfig;
use Socialtext::TT2::Renderer;
use File::Path qw(mkpath);
use File::Basename qw(basename);
use Socialtext::Helpers;
use YAML;
use namespace::clean -except => 'meta';

use constant code_base => Socialtext::AppConfig->code_base;
use constant is_dev_env => Socialtext::AppConfig->is_dev_env;
use constant static_path => Socialtext::Helpers->static_path;

our $FILES = YAML::LoadFile(code_base . '/skin/starfish/css/order.yaml');

has 'skin_path' => ( is => 'ro', isa => 'Str', lazy_build => 1 );
sub _build_skin_path {
    my $self = shift;
    return join('/', $self->code_base, 'skin', $self->hub->skin->skin_name);
}
has 'skin_uri' => ( is => 'ro', isa => 'Str', lazy_build => 1 );
sub _build_skin_uri {
    my $self = shift;
    return join('/', $self->static_path, 'skin', $self->hub->skin->skin_name);
}

has 'files' => (
    is => 'ro', isa => 'ArrayRef', lazy_build => 1, auto_deref => 1,
);
sub _build_files {
    my $self = shift;
    return [ map { $self->skin_path . "/css/$_" } @$FILES ];
}

extends 'Socialtext::Rest';

sub GET {
    my ($self, $rest) = @_;

    my $dir = Socialtext::Paths::cache_directory('theme');
    mkpath $dir unless -d $dir;

    my $account_id = $self->account_id;
    my $file = "$dir/$account_id.css";

    set_contents($file, $self->render_css) if $self->needs_update($file);

    $rest->header(
        -status               => HTTP_200_OK,
        '-content-length'     => -s $file || 0,
        -type                 => 'text/css',
        -pragma               => undef,
        '-cache-control'      => undef,
        'Content-Disposition' => q{filename="style.css"},
        '-X-Accel-Redirect'   => "/nlw/theme/$account_id/style.css",
    );
}

sub needs_update {
    my ($self, $file) = @_;

    return 1 unless -f $file;
    if ($self->is_dev_env) {
        my $latest = (sort map { (stat($_))[9] } $self->files)[-1];
        return $latest > (stat($file))[9];
    }
    return 0;
}

sub render_css {
    my $self = shift;

    my $renderer = Socialtext::TT2::Renderer->instance;
    
    my $css = '';
    for my $file ($self->files) {
        next unless -f $file;
        if ($file =~ m{\.tt2$}) {
            $css .= $renderer->render(
                template => basename($file),
                paths => [ $self->skin_path . "/css" ],
                vars => {
                    skin => $self->skin_uri,
                }
            );
        }
        else {
            $css .= get_contents($file);
        }
        $css .= "\n";
    }

    return $css;
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
