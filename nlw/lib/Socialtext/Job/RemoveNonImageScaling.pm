package Socialtext::Job::RemoveNonImageScaling;
# @COPYRIGHT@
use Moose;
use File::Basename;
use File::Find::Rule;
use File::Spec;
use Socialtext::File;
use Socialtext::Paths;
use Socialtext::System qw/shell_run/;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

sub do_work {
    my $self = shift;
    my $ws   = $self->workspace;

    my $dir = File::Spec->catdir(
        Socialtext::Paths::plugin_directory($ws->name), 'attachments');

    my $files = $self->_mime_files($dir);
    for my $file (@$files) {
        my $mime_type = $self->_mime_type($file);
        $self->_delete_scaled_dir($file)
            if ($self->_invalid_image($mime_type));
    }

    $self->completed();
}

sub _mime_type {
    my $self = shift;
    my $mime_file = shift;
    
    my $type =  Socialtext::File::get_contents($mime_file);
}

sub _delete_scaled_dir {
    my $self = shift;
    my $path = shift;

    my($filename, $dir, $suffix) = fileparse($path);
    Socialtext::File::remove_directory("$dir/scaled");
}

sub _invalid_image {
    my $self = shift;
    my $mime = shift;
    return $mime !~ /^image/;
}

sub _mime_files {
    my ($self, $dir) = @_;

    my @files = File::Find::Rule->file()
       ->mindepth(3) # exclude metadata files
       ->name(qr/-mime$/) 
       ->in($dir);

    return \@files;
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 1);
1;
