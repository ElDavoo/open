package Socialtext::Rest::Upload;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Rest::Entity';
use Socialtext::HTTP ':codes';
use Socialtext::JSON;
use Socialtext::File;
use Socialtext::Rest::Uploads;
use File::Type;

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

    $rest->header( 'Content-type' => $mime );
    return Socialtext::File::get_contents_binary($file);
}

1;

=head1 NAME

Socialtext::Rest::Upload - Retrieve temporarily uploaded files

=head1 SYNOPSIS

    GET /data/uploads/:id

=head1 DESCRIPTION

Grab the content of an uploaded file

=cut
