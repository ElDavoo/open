package Socialtext::Rest::Upload;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Rest::Entity';
use Socialtext::HTTP ':codes';
use Socialtext::JSON;
use Socialtext::File;
use Socialtext::Rest::Uploads;
use Socialtext::Upload;
use File::Temp qw(tempfile);
use File::Copy qw/copy move/;
use Fatal qw/copy move/;
use Socialtext::Exceptions qw/data_validation_error/;
use Try::Tiny;

my %RESIZERS = (
    profile   => 'Socialtext::People::ProfilePhoto',
    group     => 'Socialtext::Group::Photo',
    account   => 'Socialtext::AccountLogo',
    sigattach => 'Socialtext::Signal::Attachment',
);

sub permission      { +{} }
sub allowed_methods {'GET'}
sub entity_name     { "Upload" }
sub nonexistence_message { "Uploaded file not found." }

sub GET {
    my ($self, $rest) = @_;
    my $rv;
    try   { $rv = $self->_GET() }
    catch { $rv = $self->handle_rest_exception($_) };
    return $rv;
}

sub _GET {
    my $self = shift;
    my $user = $self->rest->user;

    return $self->not_authorized unless $user->is_authenticated;

    my $uuid = $self->id;

    my $upload = try { Socialtext::Upload->Get(attachment_uuid => $uuid) };
    my $file;
    unless ($upload &&
            $upload->is_temporary &&
            $upload->creator_id == $user->user_id) 
    {
        return $self->http_404_force;
    }

    my $file = $upload->temp_filename;
    unless (-f $file) {
        return $self->http_404_force;
    }

    # Support image resizing /?resize=group:small will resize for a
    # Socialtext::Group::Photo using the small version
    my $blob;
    if (my $resize = $self->rest->query->param('resize')) {
        data_validation_error "You can only resize images"
            unless $upload->is_image;

        my ($resizer, $size) = split ':', $resize;
        $size ||= 'small';

        my $rclass = $RESIZERS{$resizer}
            or data_validation_error "Unknown resizer: $resizer";
        eval "require $rclass";
        if ($@) {
            warn "while looking for resizer: $@";
            die "Unable to resize image.\n";
        }

        try  {
            my $temp;
            (undef, $temp) = tempfile('/tmp/resizeXXXXXX',
                OPEN => 0, UNLINK => 1);
            copy($file, $temp);
            $rclass->Resize($size, $temp);
            $blob = Socialtext::File::get_contents_binary($temp);
        }
        catch {
            die "Unable to resize image: $_";
        };
    }
    else {
        $upload->binary_contents(\$blob);
    }

    $self->rest->header(-type => $upload->mime_type);
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
