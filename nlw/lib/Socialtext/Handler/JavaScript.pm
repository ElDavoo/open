package Socialtext::Handler::JavaScript;
# @COPYRIGHT@
use Moose;
use methods;
use Socialtext::HTTP ':codes';
use Socialtext::JavaScript::Builder;
use Socialtext::AppConfig;
use File::Basename qw(basename);
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest';
my $code_base = Socialtext::AppConfig->code_base;

has 'path' => (
    is => 'ro', isa => 'Maybe[Str]', lazy_build => 1,
);

my %DIR = (
    'jquery-1.4.2.js' => 'javascript/contrib',
    'jquery-1.4.2.min.js' => 'javascript/contrib',
    'jquery-1.4.4.js' => 'javascript/contrib',
    'jquery-1.4.4.min.js' => 'javascript/contrib',
    'push-client.js' => 'plugin/widgets/share/javascript',
);

method GET ($rest) {
    my $file = $self->__file__;
    my $builder = Socialtext::JavaScript::Builder->new;

    my ($url, $path);

    if ($builder->is_target($file)) {
        $path = $builder->target_path($file);
        $url = "/nlw/js/$file";
        $builder->build($file) if !-f $path or $ENV{NLW_DEV_MODE};
    }
    elsif (my $dir = $DIR{$file}) {
        $path = "$code_base/$dir/$file";
        $url = "/nlw/static/$dir/$file";
    }

    $rest->header(
        -status               => HTTP_200_OK,
        '-content-length'     => -s $path,
        -type                 => 'application/javascript',
        -pragma               => undef,
        '-cache-control'      => undef,
        'Content-Disposition' => "filename=\"$file\"",
        '-X-Accel-Redirect'   => $url,
    );
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

__END__

=head1 NAME

Socialtext::Handler::JavaScript - rebuilds JS as needed in a dev-env

=head1 SYNOPSIS

  # its mapped in automatically in "uri_map.yaml"

=head1 DESCRIPTION

Rebuilds JS as necessary in your dev-env.

=cut
