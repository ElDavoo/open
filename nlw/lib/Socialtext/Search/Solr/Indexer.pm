package Socialtext::Search::Solr::Indexer;
# @COPYRIGHT@
use Date::Parse qw(str2time);
use DateTime::Format::Pg;
use DateTime;
use Moose;
use MooseX::AttributeInflate;
use MooseX::AttributeHelpers;
use Socialtext::Timer;
use Socialtext::Hub;
use Socialtext::Workspace;
use Socialtext::Page;
use Socialtext::User;
use Socialtext::Attachment;
use Socialtext::Attachments;
use Socialtext::Log qw(st_log);
use Socialtext::Search::ContentTypes;
use Socialtext::Search::Utils;
use Socialtext::File;
use WebService::Solr;
use Socialtext::WikiText::Parser::Messages;
use Socialtext::WikiText::Emitter::Messages::Solr;
use Socialtext::String;
use namespace::clean -except => 'meta';

=head1 NAME

Socialtext::Search::Solr::Indexer

=head1 SYNOPSIS

  my $i = Socialtext::Search::Solr::Factory->create_indexer($workspace_name);
  $i->index_workspace(...);
  $i->index_page(...);
  $i->index_attachment(...);

=head1 DESCRIPTION

Index documents using Solr;

=cut

extends 'Socialtext::Search::Indexer';
extends 'Socialtext::Search::Solr';

has '_docs' => (
    is => 'rw', isa => 'ArrayRef[WebService::Solr::Document]',
    metaclass => 'Collection::Array',
    default => sub { [] },
    provides => { push => '_add_doc' },
);

use constant FUDGE_ATTACH_REVS => 25;

######################
# Workspace Handlers
######################

# Make sure we're in a valid workspace, then recreate the index and get all
# the active pages, add each of them, and then add all the attachments on each
# page. 
sub index_workspace {
    my ( $self, $ws_name ) = @_;
    $self->delete_workspace($ws_name);
    _debug("Starting to retrieve page ids to index workspace.");
    for my $page_id ( $self->hub->pages->all_ids ) {
        my $page = $self->_load_page($page_id) || next;
        $self->_add_page_doc($page);
        $self->_index_page_attachments($page);
    }
    $self->_commit;
}

# Delete the index directory.
sub delete_workspace {
    my $self = shift;
    my $ws_name = shift || $self->ws_name;
    my $ws = Socialtext::Workspace->new(name => $ws_name);
    my $ws_id = $ws->workspace_id;
    
    Socialtext::Timer->Continue('solr_del_wksp');
    $self->solr->delete_by_query("w:$ws_id");
    $self->_commit;
    Socialtext::Timer->Pause('solr_del_wksp');
}

# Get all the active attachments on a given page and add them to the index.
sub _index_page_attachments {
    my ( $self, $page ) = @_;
    _debug( "Retrieving attachments from page: " . $page->id );
    my $attachments = $page->hub->attachments->all( page_id => $page->id );
    _debug( sprintf "Retreived %d attachments", scalar @$attachments );
    for my $attachment (@$attachments) {
        $self->_add_attachment_doc($attachment);
    }
}

##################
# Page Handling
##################

# Load up the page and add its content to the index.
sub index_page {
    my ( $self, $page_uri ) = @_;
    my $page = $self->_load_page($page_uri, 'deleted ok') || return;
    return $self->delete_page($page_uri) if $page->deleted;
    $self->_add_page_doc($page);
    $self->_index_page_attachments($page);
    $self->_commit;
}

# Remove the page from the index.
sub delete_page {
    my ( $self, $page_uri ) = @_;
    my $page = $self->_load_page($page_uri, 'deleted ok') || return;
    my $key = $self->page_key($page->id);
    $self->solr->delete_by_query("page_key:$key");
    $self->_commit;
}

# Create a new Document object and set it's fields.  Then delete the document
# from the index using 'key', which should be unique, and then add the
# document to the index.  The 'key' is just the page id.
sub _add_page_doc {
    my $self = shift;
    my $page = shift;

    Socialtext::Timer->Continue('solr_page');

    my $ws_id = $self->workspace->workspace_id;
    my $id = join(':',$ws_id,$page->id);
    st_log->debug("Indexing page doc $id");

    my $mtime = _date_header_to_iso($page->metadata->Date);
    my $editor_id = $page->last_edited_by->user_id;
    my $ctime = _date_header_to_iso($page->original_revision->metadata->Date);
    my $creator_id = $page->creator->user_id;

    my $revisions = $page->revision_count;

    Socialtext::Timer->Continue('solr_page_body');
    my $body = $page->_to_plain_text;
    _scrub_body(\$body);
    Socialtext::Timer->Pause('solr_page_body');

    my @fields = (
        [id => $id],
        # it is important to call this 'w' instead of 'workspace_id', because
        # we specify it many times for inter-workspace search, and we face 
        # lengths on the URI limit.
        [w => $ws_id],
        [w_title => $self->workspace->title],
        [doctype => 'page'], 
        [pagetype => $page->metadata->Type],
        [page_key => $self->page_key($page->id)],
        [title => $page->title],
        [date => $mtime],
        [created => $ctime],
        [editor => $editor_id],
        [creator => $creator_id],
        [revisions => $revisions],
        [body => $body],
        map { [ tag => $_ ] } @{$page->metadata->Category},
    );

    $self->_add_doc(WebService::Solr::Document->new(@fields));

    Socialtext::Timer->Pause('solr_page');
}

sub page_key {
    my $self = shift;
    my $page_id = shift;

    join '__', $self->workspace->workspace_id, $page_id;
}

########################
# Attachment Handling
########################

# Load an attachment and then add it to the index.
sub index_attachment {
    my ( $self, $page_uri, $attachment_id ) = @_;

    my $attachment = Socialtext::Attachment->new(
        hub     => $self->hub,
        id      => $attachment_id,
        page_id => $page_uri,
    )->load;
    _debug("Loaded attachment: page_id=$page_uri attachment_id=$attachment_id");

    $self->_add_attachment_doc($attachment);
    $self->_commit();
}

# Remove an attachment from the index.
sub delete_attachment {
    my ( $self, $page_uri, $attachment_id ) = @_;
    my $ws_id = $self->workspace->workspace_id;
    my $page = $self->_load_page($page_uri, 'deleted ok') || return;
    my $id = join(':',$ws_id,$page->id,$attachment_id);
    $self->solr->delete_by_id($id);
    $self->_commit();
}

# Get the attachments content, create a new Document, set the Doc's fields,
# and add the Document to the index.
sub _add_attachment_doc {
    my $self = shift;
    my $att = shift;

    Socialtext::Timer->Continue('solr_add_attach');

    my $ws_id = $self->workspace->workspace_id;
    my $id = join(':',$ws_id,$att->page_id,$att->id);
    st_log->debug("Indexing attachment doc $id <".$att->filename.">");

    my $date = _date_header_to_iso($att->Date);
    my $editor_id = $att->uploaded_by->user_id;

    # XXX: this code assumes there's just one attachment revision
    # counteract the revisions boost by providing a dummy constant
    my $revisions = FUDGE_ATTACH_REVS;

    Socialtext::Timer->Continue('solr_attach_body');
    my $body = $att->to_string;
    _scrub_body(\$body);
    my $key = $self->page_key($att->page_id);
    $self->_truncate( $key, \$body );
    Socialtext::Timer->Pause('solr_attach_body');

    _debug( "Retrieved attachment content.  Length is " . length $body );
    return unless length $body;

    my @fields = (
        [id => $id],
        # it is important to call this 'w' instead of 'workspace_id', because
        # we specify it many times for inter-workspace search, and we face 
        # lengths on the URI limit.
        [w => $ws_id], 
        [w_title => $self->workspace->title],
        [doctype => 'attachment'],
        [page_key => $key],
        [attach_id => $att->id],
        [title => $att->filename],
        [filename => $att->filename],
        [editor => $editor_id],
        [creator => $editor_id],
        [date => $date],
        [created => $date],
        [revisions => $revisions],
        [body => $body],
    );

    $self->_add_doc(WebService::Solr::Document->new(@fields));
    Socialtext::Timer->Pause('solr_add_attach');
}

# Make sure the text we index is not bigger than 20 million characters, which
# is about 20 MB.  Unicode might screw us here with its multibyte characters,
# but I'm not too worried about it.
# 
# The 20 MB figure was arrived at by history which is no longer relevant.
#
# See {link dev-tasks [KinoSearch - Maximum File Size Cap]} for more
# information.
sub _truncate {
    my ( $self, $key, $text_ref ) = @_;
    my $max_size = 20 * ( 1024**2 );
    return if length($$text_ref) <= $max_size;
    my $info = "ws = " . $self->ws_name . " key = $key";
    _debug("Truncating text to $max_size characters:  $info");
    $$text_ref = substr( $$text_ref, 0, $max_size );
}

##################
# Signal Handling
##################

sub index_signal {
    my ( $self, $signal ) = @_;
    return $self->delete_signal($signal->signal_id) if $signal->is_hidden;
    $self->_add_signal_doc($signal);
    $self->_commit;
}

# Remove the signal from the index.
sub delete_signal {
    my ( $self, $signal_id ) = @_;
    $self->solr->delete_by_query("signal_key:$signal_id");
    $self->_commit;
}

# Create a new Document object and set it's fields.  Then delete the document
# from the index using 'key', which should be unique, and then add the
# document to the index.  The 'key' is just the signal id.
sub _add_signal_doc {
    my $self = shift;
    my $signal = shift;

    Socialtext::Timer->Continue('solr_signal');

    my $id = $signal->signal_id;
    st_log->debug("Indexing signal doc $id");

    my $ctime = _pg_date_to_iso($signal->at);
    my $recip = $signal->recipient_id || 0;
    my @user_topics = $signal->user_topics;
    Socialtext::Timer->Continue('solr_signal_body');
    my ($body, $external_links, $page_links) = $self->render_signal_body($signal);
    _scrub_body(\$body);
    Socialtext::Timer->Pause('solr_signal_body');

    my $in_reply_to = $signal->in_reply_to;
    my $is_question = $body =~ m/\?\s*$/ ? 1 : 0;

    my @fields = (
        [id => $id],
        [w => 0],
        [doctype => 'signal'], 
        [signal_key => $id],
        [date => $ctime], [created => $ctime],
        [creator => $signal->user_id],
        [creator_name => $signal->user->best_full_name],
        [body => $body],
        [is_question => $is_question],
        [pvt => $recip ? 1 : 0],
        [dm_recip => $recip],
        (map { [a => $_] } @{ $signal->account_ids }),
        ($in_reply_to ? [reply_to =>$in_reply_to->user_id] : ()),
        (map { [mention => $_->user_id] } @user_topics ),
        (map { [link_w => $_->[0]],
               [link_page_key => $_->[1]],
            } @$page_links),
        (map { [link => $_] } @$external_links),
    );

    $self->_add_doc(WebService::Solr::Document->new(@fields));

    Socialtext::Timer->Pause('solr_signal');
}

sub render_signal_body {
    my $self = shift;
    my $signal = shift;

    my @external_links;
    my @page_links;
    my $parser = Socialtext::WikiText::Parser::Messages->new(
        receiver => Socialtext::WikiText::Emitter::Messages::Solr->new(
            callbacks => {
                href_link => sub {
                    my $ast = shift;
                    my $link = $ast->{attributes}{href};
                    push @external_links, $link;
                },
                page_link => sub {
                    my $ast = shift;
                    my $wksp = Socialtext::Workspace->new(name => $ast->{workspace_id});
                    return unless $wksp;
                    my $wksp_id = $wksp->workspace_id;
                    my $pid = Socialtext::String::uri_unescape($ast->{page_id});
                    $pid = Socialtext::String::title_to_id($pid, 'no escape');
                    push @page_links, [ $wksp_id, "$wksp_id:$pid" ];
                },
            },
        ),
    );
    my $body = $parser->parse($signal->body);
    return $body, \@external_links, \@page_links;
}

##################
# Person Handling
##################

sub index_person {
    my ( $self, $user ) = @_;
    if ($user->is_deleted or $user->is_profile_hidden) {
        return $self->delete_person($user->user_id);
    }
    $self->_add_person_doc($user);
    $self->_commit;
}

# Remove the person from the index.
sub delete_person {
    my ( $self, $user_id ) = @_;
    $self->solr->delete_by_query("person_key:$user_id");
    $self->_commit;
}

# Create a new Document object and set it's fields.  Then delete the document
# from the index using 'key', which should be unique, and then add the
# document to the index.  The 'key' is just the user id.
sub _add_person_doc {
    my $self = shift;
    my $user = shift;

    Socialtext::Timer->Continue('solr_person');

    my $profile = eval {
        Socialtext::People::Profile->GetProfile($user);
    };
    if (!$profile) {
        Socialtext::Timer->Pause('solr_person');
        return;
    }

    my $id = $user->user_id;
    st_log->debug("Indexing person $id");

    my $mtime = _pg_date_to_iso($profile->last_update);
    my @tags = map { [tag => $_] } keys %{$profile->tags};

    my @fields = (
        [id => $id],
        [w => 0],
        [a => $user->primary_account_id],
        [doctype => 'person'], 
        [person_key => $id],
        [date => $mtime], 

        @tags,
        [num_tags => scalar @tags],

        [first_name_pf_s => $user->first_name],
        [last_name_pf_s => $user->last_name],
        [email_address_pf_s => $user->email_address],
        [username_pf_s => $user->username],
        # allow fuzzy/stem searching on the full name, for fun.
        [name_pf_t => $user->best_full_name],
    );

    my $prof_fields = $profile->fields->to_hash;
    for my $field ($profile->fields->all) {
        my $solr_field = $field->solr_field_name;
        if ($field->is_relationship) {
            push @fields, [$solr_field => $profile->get_reln_id($field->name)];
        }
        else {
            push @fields, [$solr_field => $profile->get_attr($field->name)];
        }
    }

    $self->_add_doc(WebService::Solr::Document->new(@fields));

    Socialtext::Timer->Pause('solr_person');
}


#################
# Miscellaneous 
#################

# Given a page_id, retrieve the corresponding Page object.
sub _load_page {
    my ( $self, $page_id, $deleted_ok ) = @_;
    _debug("Loading $page_id");
    my $page = $self->hub->pages->new_page($page_id);
    if ( not defined $page ) {
        _debug("Could not load page $page_id");
    }
    elsif ( !$deleted_ok and $page->deleted ) {
        _debug("Page $page_id is deleted, skipping.");
        undef $page;
    }
    _debug("Finished loading $page_id");
    return $page;
}

# Send a debugging message to syslog.
sub _debug {
    my $msg = shift || "(no message)";
    $msg = __PACKAGE__ . ": $msg";
    st_log->debug($msg);
}

sub _pg_date_to_iso {
    my $pgdate = shift;
    $pgdate =~ s/Z$//;
    my $dt = DateTime::Format::Pg->new(
        server_tz => 'UTC',
    );
    my $utc_time = $dt->parse_timestamptz( $pgdate );
    my $date = DateTime->from_epoch( epoch => $utc_time->epoch );
    $date->set_time_zone('UTC');
    return $date->iso8601 . 'Z';
}

sub _date_header_to_iso {
    my $hdr = shift;
    my $date = DateTime->from_epoch(epoch => str2time($hdr));
    $date->set_time_zone('UTC');
    return $date->iso8601 . 'Z';
}

sub _scrub_body {
    my $body_ref = shift;
    $$body_ref =~ s/[[:cntrl:]]+/ /g; # make Jetty happy
}

sub _commit {
    my $self = shift;

    _debug("Preparing to finalize index.");
    Socialtext::Timer->Continue('solr_commit');
    my $docs = $self->_docs;
    eval {
        # First, explicitly delete all previously indexed content for
        # this page
        my %page_keys;
        for my $d (@$docs) {
            next unless $d->{page_key};
            $page_keys{$d->{page_key}}++;

        }
        Socialtext::Timer->Continue('solr_delete');
        for my $key (keys %page_keys) {
            $self->solr->delete_by_query("page_key:$key");
        }
        Socialtext::Timer->Pause('solr_delete');

        if (@$docs) {
            Socialtext::Timer->Continue('solr_add');
            st_log->debug('Adding '.@$docs.' documents to index');
            $self->solr->add($docs);
            Socialtext::Timer->Pause('solr_add');
        }

        $self->solr->commit();
    };
    my $err = $@;
    Socialtext::Timer->Pause('solr_commit');
    die $err if $err;
    _debug("Done finalizing index.");
}

__PACKAGE__->meta->make_immutable;
1;
