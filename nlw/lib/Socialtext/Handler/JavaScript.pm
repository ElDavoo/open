package Socialtext::Handler::JavaScript;
use Moose;
use Socialtext::HTTP ':codes';
use Socialtext::MakeJS;
use Socialtext::AppConfig;
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest';
my $code_base = Socialtext::AppConfig->code_base;

sub GET {
    my ($self, $rest) = @_;
    my $skin = $self->skin;
    my $file = $self->file;
    my $path = "$code_base/skin/$skin/javascript/$file";

    Socialtext::MakeJS->Build($skin, $file);
    
    unless (-f $path) {
        warn "Don't know how to build $path";
        return $self->no_resource($file);
    }

    $rest->header(
        -status               => HTTP_200_OK,
        '-content-length'     => -s $path,
        -type                 => 'application/javascript',
        -pragma               => undef,
        '-cache-control'      => undef,
        'Content-Disposition' => "filename=\"$file\"",
        '-X-Accel-Redirect'   => "/nlw/static/skin/$skin/javascript/$file",
    );
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
