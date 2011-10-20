package Socialtext::Handler::Grids;
# @COPYRIGHT@
use Moose;
use methods-invoker;
use Socialtext::HTTP qw(:codes);
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest::Entity';

sub GET_css {
    my $self = shift;
    my $rest = shift;

    my $width = $self->width;
    my $cols = $self->cols;
    my $output = "grids.$cols.$width";

    my $sass = Socialtext::SASSy->new(
        filename => 'grids.fixed',
        output_filename => $output,
        dir_name => 'Global',
        params => {
            containers => $cols,
            width => "${width}px",
            margin => '10px',
        },
    );
    $sass->render if $sass->needs_update;

    my $size = -s $sass->sass_file;

    $rest->header(
        -status               => HTTP_200_OK,
        '-content-length'     => $size || 0,
        -type                 => 'text/css',
        -pragma               => undef,
        '-cache-control'      => undef,
        'Content-Disposition' => qq{filename="$output.css.txt"},
        '-X-Accel-Redirect'   => $sass->protected_uri("$output.css"),
    );
}
