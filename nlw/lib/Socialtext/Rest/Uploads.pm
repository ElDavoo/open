package Socialtext::Rest::Uploads;
# @COPYRIGHT@
use Moose;
extends 'Socialtext::Rest::Collection';
use Socialtext::HTTP ':codes';
use Data::UUID;
use Socialtext::File;
use Socialtext::JSON qw/encode_json/;
use namespace::clean -except => 'meta';

our $UPLOAD_DIR = "/tmp/uploads";

sub permission { +{} }
sub collection_name { 'Uploads' }

has 'uuid' => (
    is => 'ro', isa => 'Data::UUID',
    lazy_build => 1,
);
sub _build_uuid { new Data::UUID }

sub _entities_for_query {
    my $self = shift;
    unless ($self->rest->user->is_business_admin) {
        $self->rest->header( -status => HTTP_401_Unauthorized );
        return '';
    }
    my @dirs;
    opendir my $dir, $UPLOAD_DIR or return ();
    while (my $file = readdir $dir) {
        next if $file =~ /^\./;
        push @dirs, $file;
    }
    return @dirs;
}

sub _entity_hash {
    my $self  = shift;
    my $id = shift;
    return { name => $id, uri => "/data/uploads/$id" };
}

sub POST_file {
    my $self = shift;
    my $rest = shift;

    unless ($self->rest->user->is_authenticated) {
        return $self->_post_failure(
            $rest, HTTP_401_Unauthorized, 'must be a group admin'
        );
    }

    my $file = $rest->query->{'file'};
    unless ($file) {
        return $self->_post_failure(
            $rest, HTTP_400_Bad_Request, 'photo is a required argument'
        );
    }

    my $uuid = $self->uuid->create_str();
    eval {
        my $fh = $file->[0];
        my $blob = do { local $/; <$fh> };
        mkdir($UPLOAD_DIR, 0777) unless -d $UPLOAD_DIR;
        my $temp = "$UPLOAD_DIR/$uuid";
        Socialtext::File::set_contents_binary($temp, $blob);
    };
    if ( $@ ) {
        return $self->_post_failure(
            $rest, HTTP_400_Bad_Request, "could not save image"
        );
    }

    $rest->header( -status => HTTP_201_Created );
    return encode_json({
        status => 'success',
        id => $uuid,
        message => 'photo uploaded',
    });
}

sub _post_failure {
    my $self    = shift;
    my $rest    = shift;
    my $status  = shift;
    my $message = shift;

    $rest->header($rest->header(), -status => $status);
    return encode_json( {status => 'failure', message => $message} );
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 NAME

Socialtext::Rest::Uploads - Upload temporary files for later use

=head1 SYNOPSIS

    GET /data/uploads
    POST /data/uploads

=head1 DESCRIPTION

Upload files for temporary use as logos, etc

=cut
