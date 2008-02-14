# @COPYRIGHT@
package Socialtext::AttachmentsUIPlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';

use Class::Field qw( const field );
use IO::File;
use Socialtext::AppConfig;
use Socialtext::Helpers;
use Socialtext::Exceptions;
use Socialtext::TT2::Renderer;
use Socialtext::l10n qw(loc system_locale);
use Socialtext::BrowserDetect;

sub class_id { 'attachments_ui' }
const class_title => 'Attachments';
const cgi_class   => 'Socialtext::AttachmentsUI::CGI';
field 'display_limit_value';

const sortdir => {    #default directions
    Subject        => 0,
    From           => 0,
    Content_Length => 0,
    Date           => 1,
    Content_MD5    => 0
};

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add( action => 'listall' );       # XXX "backwards compatibility"
    $registry->add( action => 'attachments' );   # XXX "backwards compatibility"
    $registry->add( action => 'attachments_upload' );
    $registry->add( action => 'attachments_download' );
    $registry->add( action => 'attachments_delete' );
    $registry->add( action => 'attachments_listall' );
}

# backwards compatibility for old links
sub listall {
    my $self = shift;
    $self->redirect('action=attachments_listall');
}

# more backwards comapt
sub attachments {
    my $self = shift;
    $self->redirect(
        '?page_name=' . $self->cgi->page_name . ';js=attachments_div_on' );
}

sub attachments_download {
    my $self = shift;
    my $id      = $self->cgi->id;

    # find filename
    my $attachment = $self->hub->attachments->new_attachment( id => $id );

    eval { $attachment->load };
    return $self->failure_message(
        loc("Attachment not found. The page name, file name or identifer number in the link may be incorrect, or the attachment may have been deleted or is not present in this workspace."),
        $@, $self->hub->pages->current

    ) if $@;

    my $file = $attachment->full_path;

    unless ( -e $file ) {

        # TODO: make 404 a real HTTP 404
        die "404: File Not Found: '$file'";
    }
    my $fh = new IO::File $file, 'r';
    die "Cannot read $file: $!" unless $fh;

    my $mime_type = $attachment->mime_type;
    my $charset = 'UTF-8';

    if ( $mime_type =~ /^text/ ) {
        $charset = $attachment->charset(system_locale());
    }

    # Add the headers for an attachment
    my $filename = $attachment->filename;
    $self->log_action("DOWNLOAD_ATTACHMENT", $filename);
    
    # XXX: should test with safari
    if( Socialtext::BrowserDetect::ie() ) {
        $filename = $self->uri_escape($filename);
    }

    $self->hub->headers->add_attachment(
        filename => $filename,
        len      => -s $file,
        type     => $mime_type,
        charset  => $charset,
    );

    # Erase Content-Disposition if we want the attachment inline.
    if ( not $attachment->should_popup or $self->cgi->as_page ) {
        $self->hub->headers->content_disposition(undef);
    }
    # return the glob so the framework can write it down
    return $fh;
}

sub attachments_upload {
    my $self = shift;

    my @files = $self->cgi->file;
    my @embeds = $self->cgi->embed unless $self->cgi->editmode;
    my @unpacks = $self->cgi->unpack;

    my $error = $self->process_attachments_upload(
        files  => \@files,
        embed  => \@embeds,
        unpack => \@unpacks,
    );

    return $self->_finish(
        error => $error,
        files => $self->{_attachment_info},
    );
}

sub process_attachments_upload {
    my $self = shift;
    my %p    = @_;

    my @files = @{$p{files}};
    my @embeds = @{$p{embed}};
    my @unpacks = @{$p{unpack}};

    my $count = grep { -s $_->{handle} } @files;

    return loc('The file you are trying to upload does not exist')
        unless $count;

    return loc('You dont have permission to upload attachments')
        unless $self->hub->checker->check_permission('attachments');

    my $error = '';
    for (my $i=0; $i < $count; $i++) {
        my $error_code = $self->save_attachment(
            $files[$i],
            $embeds[$i],
            $unpacks[$i],
        );
        if ($error_code) {
            $error_code =~ s/\. at.*//s;    # grr... stinkin auto-added backtrace.
            $error .= $error_code;
        }

    }
    return $error;
}

sub _finish {
    my ($self, %args) = @_;
    my $renderer = Socialtext::TT2::Renderer->instance;
    return $renderer->render(
        template => 'view/attachmentresult',
        vars     => \%args,
    );
}

sub save_attachment {
    my $self = shift;
    my $file = shift; # [in] File object/hash from CGI
    my $embed = shift; # [in/optional] boolean - true if link to file should be embedded in page; default to true
    my $unpack = shift; # [in/optional] boolean - true if ZIP file should be unpacked; default to true

    my $filename;
    eval {
        $filename = $file->{filename} . '';
        my @files = $self->hub->attachments->from_file_handle(
            fh     => $file->{handle},
            embed  => $embed ? 1 : 0,
            unpack => $unpack ? 1 : 0,

            # this stringification is to remove tied weirdness:
            filename => $filename,
            creator  => $self->hub->current_user,
        );
        for my $file (@files) {
            $self->{_attachment_info}{$file->filename} = $file->id;
        }
        $self->log_action("UPLOAD_ATTACHMENT", $filename);
    };

    return $@;
}

sub attachments_listall {
    my $self = shift;

    $self->screen_template('view/attachmentslist');
    $self->render_screen(
        rows =>
            $self->_table_rows( $self->hub->attachments->all_in_workspace() ),
        display_title => loc("All Files"),
    );
}

sub _table_rows {
    my $self        = shift;
    my $attachments = shift;

    my @rows;
    for my $att (@$attachments) {
        my $page = $self->hub->pages->new_page( $att->{page_id} );

        push @rows, {
            link     => $self->_attachment_download_link($att),
            id       => $att->{id},
            filename => $att->{filename},
            user     => $att->{from},
            date     => $self->hub->timezone->date_local( $att->{date} ),
            page     => {
                uri   => $page->uri,
                link  =>
                    Socialtext::Helpers->page_display_link_from_page($page),
            },
            size => $att->{length},
        };
    }

    return \@rows;
}

sub _attachment_download_link {
    my $self = shift;
    my $attachment = shift;

    my $workspace     = $self->hub->current_workspace->name;
    my $filename_uri  = $self->uri_escape( $attachment->{filename} );
    my $filename_html = $self->html_escape( $attachment->{filename} );
    my $page          = $self->hub->pages->new_page( $attachment->{page_id} );
    my $page_uri      = $page->uri;

    return qq|<a href="/data/workspaces/$workspace/attachments/$page_uri:|
         . qq|$attachment->{id}/original/$filename_uri">$filename_html</a>|;
}

sub attachments_delete {
    my $self = shift;
    return unless $self->hub->checker->check_permission('delete');

    for my $attachment_junk ( $self->cgi->selected ) {
        my ( $page_id, $id, undef ) = map { split ',' } $attachment_junk;
        my $attachment = $self->hub->attachments->new_attachment(
            id      => $id,
            page_id => $page_id,
        );
        $attachment->delete( user => $self->hub->current_user );
    }

    if ( $self->cgi->caller_action eq 'attachments_listall' ) {
        return $self->redirect('action=attachments_listall');
    }

    # If called via AJAX we have nothing to return
    return;
}

#------------------------------------------------------------------------------#
package Socialtext::AttachmentsUI::CGI;

use base 'Socialtext::CGI';
use Socialtext::CGI qw( cgi );

cgi 'direction';
cgi 'file' => '-upload';  #XXX Looks like the string is already encoded. hmmm???
cgi 'id' => '-clean_path';
cgi 'sortby';
cgi 'redirected';
cgi 'caller_action';
cgi 'button';
cgi 'checkbox';
cgi 'selected';
cgi 'filename';
cgi 'caller_action';
cgi 'page_name';
cgi 'embed';
cgi 'editmode';
cgi 'as_page';
cgi 'unpack';
cgi 'size';

1;
