package Socialtext::Handler::Theme;
# @COPYRIGHT@
use Moose;
use Socialtext::HTTP ':codes';
use Socialtext::Paths;
use Socialtext::File qw(get_contents set_contents);
use File::Path qw(mkpath);
use Socialtext::AppConfig;
use namespace::clean -except => 'meta';

my $code_base = Socialtext::AppConfig->code_base;
my $is_dev_env = Socialtext::AppConfig->is_dev_env;
my $s5 = "$code_base/skin/s5";

extends 'Socialtext::Rest';

my @files = map { "$s5/css/$_" } qw(reset.css text.css 960.css st.css);

sub GET {
    my ($self, $rest) = @_;

    my $dir = Socialtext::Paths::cache_directory('theme');
    mkpath $dir unless -d $dir;

    my $account_id = $self->account_id;
    my $file = "$dir/$account_id.css";

    set_contents($file, $self->render_css) if $self->needs_update($file);

    $rest->header(
        -status               => HTTP_200_OK,
        '-content-length'     => -s $file,
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
    if ($is_dev_env) {
        my $latest = (sort map { (stat($_))[9] } @files)[-1];
        return $latest > (stat($file))[9];
    }
    return 0;
}

sub render_css {
    my $self = shift;
    
    my $css = '';
    for my $file (@files) {
        $css .= get_contents($file) . "\n" if -f $file;
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
