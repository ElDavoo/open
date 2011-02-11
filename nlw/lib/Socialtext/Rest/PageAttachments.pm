package Socialtext::Rest::PageAttachments;
# @COPYRIGHT@

use warnings;
use strict;

use base 'Socialtext::Rest::Attachments';

use Fcntl ':seek';
use File::Temp 'tempfile';
use Socialtext::HTTP ':codes';

=head2 POST

Create a new attachment.  The name must be passed in using the C<name> CGI
parameter.  If creation is successful, return 201 and the Location: of
the new attachment.

=cut

sub POST {
    my ( $self, $rest ) = @_;

    return $self->no_workspace() unless $self->workspace;
    return $self->not_authorized() unless $self->user_can('attachments');
    my $lock_check_failed = $self->page_lock_permission_fail();
    return $lock_check_failed if ($lock_check_failed);

    my $content_type = $rest->request->header_in('Content-Type');
    unless ($content_type) {
        $rest->header(
            -status => HTTP_409_Conflict,
            -type   => 'text/plain',
        );
        return 'Content-type header required';
    }
    my $page = $self->page;

    my $content_fh = tempfile(CLEANUP => 1);
    $content_fh->print($rest->getContent);
    seek $content_fh, 0, SEEK_SET;

    # read the ?name= query parameter (REST::Application can't do this)
    my $name = Apache::Request->new(Apache->request)->param('name')
        or return $self->_http_401(
            'You must supply a value for the "name" parameter.' );

    my $att = $self->hub->attachments->create(
        filename     => $name,
        fh           => $content_fh,
        creator      => $rest->user,
        Content_type => $content_type,
        page         => $page,
        page_id      => $page->id,
        embed        => 0, # don't inline a wafl for the ReST API
    );

    my $base = $self->rest->query->url( -base => 1 );
    $rest->header(
        -status   => HTTP_201_Created,
        -Location => $base . $att->download_uri('files'),
    );

    # {bz: 4286}: Record edit_save events for attachment uploads via ReST too.
    # XXX: UGH seriously? pass the page content all the way through?!
    $page->update_from_remote(user => $rest->user, content => $page->content);

    return '';
}

sub allowed_methods { 'GET, HEAD, POST' }

sub get_resource {
    my $self = shift;
    my $q = $self->rest->query;
    my $atts = $self->hub->attachments->all(
        page_id => $self->page->id,
        (map { $_ => scalar $q->param($_) } qw(order limit offset)),
    );
    return [ map { $self->_entity_hash($_) } @$atts ];
}

1;

