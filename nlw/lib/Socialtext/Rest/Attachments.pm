package Socialtext::Rest::Attachments;
# @COPYRIGHT@

use warnings;
use strict;

use base 'Socialtext::Rest::Collection';

use Fcntl ':seek';
use File::Temp 'tempfile';
use Socialtext::HTTP ':codes';
use Socialtext::Base ();

sub SORTS {
    return +{
        alpha => sub {
            $Socialtext::Rest::Collection::a->{name}
                cmp $Socialtext::Rest::Collection::b->{name};
        },
        size => sub {
            $Socialtext::Rest::Collection::b->{'content-length'} <=>
                $Socialtext::Rest::Collection::a->{'content-length'};
        },
        alpha_date => sub {
            lc($Socialtext::Rest::Collection::a->{name}
                . "\0" . $Socialtext::Rest::Collection::a->{date})
            cmp
            lc($Socialtext::Rest::Collection::b->{name}
                . "\0" . $Socialtext::Rest::Collection::b->{date});
        }
    };
}

sub allowed_methods { 'GET, HEAD, POST' }

sub _http_401 {
    my ( $self, $message ) = @_;

    $self->rest->header(
        -status => HTTP_401_Unauthorized,
        -type   => 'text/plain', );
    return $message;
}

sub bad_content {
    my ( $self, $rest ) = @_;
    $rest->header(
        -status => HTTP_415_Unsupported_Media_Type
    );
    return '';
}

sub _entity_hash {
    my ($self, $attachment) = @_;
    my $user = $self->rest->user;

    # REVIEW: URI code looks cut and pasted here and in
    # Socialtext::Rest::PageAttachments.
    return +{
        id   => $attachment->id,
        name => $attachment->filename,
        uri  => '/data/workspaces/' . Socialtext::Base->uri_escape($self->ws) . '/attachments/'
            . $attachment->page_id . ':'
            . Socialtext::Base->uri_escape($attachment->id)
            . '/original/'
            . Socialtext::Base->uri_escape($attachment->db_filename),
        'content-type'   => '' . $attachment->mime_type,    # Stringify!
        'content-length' => $attachment->Content_Length,
        date             => $attachment->Date,
        uploader         => $attachment->From,
        uploader_name     => $user->display_name,
        'page-id'        => $attachment->page_id,
        local_date  => $self->hub->timezone->date_local($attachment->Date),
    };
}

1;

