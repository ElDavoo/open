package Socialtext::Rest::Upload;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Rest::Entity';
use Socialtext::HTTP ':codes';
use Socialtext::JSON;
use Socialtext::File;
use Socialtext::Rest::Uploads;
use Socialtext::People::ProfilePhoto;
use Socialtext::Group::Photo;
use Socialtext::AccountLogo;
use File::Type;
use File::Temp qw(tempfile);

my %RESIZERS = (
    profile => 'Socialtext::People::ProfilePhoto',
    group   => 'Socialtext::Group::Photo',
    account => 'Socialtext::AccountLogo',
);

sub permission      { +{} }
sub allowed_methods {'GET'}
sub entity_name     { "Group" }

sub GET {
    my ($self, $rest) = @_;
    my $user = $self->rest->user;
    my $user_id = $user->user_id;
    my $id = $self->id;
    my $file = "$Socialtext::Rest::Uploads::UPLOAD_DIR/$id";

    unless ($user->is_authenticated) {
        $rest->header( -status => HTTP_401_Unauthorized );
        return '';
    }

    unless (-f $file) {
        $rest->header( -status => HTTP_404_Not_Found );
        return '';
    }

    my $mime = File::Type->new->mime_type($file);

    # Support image resizing /?resize=group:small will resize for a
    # Socialtext::Group::Photo using the small version
    my $blob;
    if (my $resize = $rest->query->param('resize')) {
        my ($resizer, $version) = split ':', $resize;
        die "You can only resize images" unless $mime =~ m{^image/};
        die "Bad resize string: $resize" unless $resizer and $version;
        my $rclass = $RESIZERS{$resizer} || die "Unknown resizer: $resizer";

        my $temp;
        (undef, $temp) = tempfile('/tmp/resizeXXXXXX', OPEN => 0);
        link $file, $temp;
        $rclass->Resize($version, $temp);
        $blob = Socialtext::File::get_contents_binary($temp);
        unlink $temp;
    }
    else {
        $blob = Socialtext::File::get_contents_binary($file);
    }

    $rest->header( 'Content-type' => $mime );
    return $blob;
}

1;

=head1 NAME

Socialtext::Rest::Upload - Retrieve temporarily uploaded files

=head1 SYNOPSIS

    GET /data/uploads/:id

=head1 DESCRIPTION

Grab the content of an uploaded file

=cut
