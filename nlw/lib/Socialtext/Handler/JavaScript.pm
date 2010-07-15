package Socialtext::Handler::JavaScript;
# @COPYRIGHT@
use Moose;
use Socialtext::HTTP ':codes';
use Socialtext::MakeJS;
use Socialtext::AppConfig;
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest';
my $code_base = Socialtext::AppConfig->code_base;

sub GET {
    my ($self, $rest) = @_;
    my $name = $self->name;
    my $type = $self->type;
    my $file = $self->file;

    my $dir;
    if ($type eq 'skin') {
        $dir = "skin/$name/javascript";
    }
    elsif ($type eq 'plugin') {
        $dir = "plugin/$name/share/javascript";
    }
    else {
        die "Don't know how to build $type javascript.";
    }

    Socialtext::MakeJS->Build($dir, $file);
    
    my $path = "$code_base/$dir/$file";
    my $url = "/nlw/static/$dir/$file";
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
        '-X-Accel-Redirect'   => $url,
    );
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
