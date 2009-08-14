# @COPYRIGHT@
package Socialtext::EditPlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';

use CGI;
use Class::Field qw( const );
use Socialtext::Pages;
use Socialtext::Exceptions qw( data_validation_error );
use Socialtext::l10n qw(loc);
use Socialtext::Events;
use Socialtext::Log qw(st_log);
use Socialtext::String ();
use Socialtext::JSON qw/decode_json encode_json/;

sub class_id { 'edit' }
const class_title => 'Editing Page';
const cgi_class => 'Socialtext::Edit::CGI';

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(action => 'edit');
    $registry->add(action => 'edit_save');
    $registry->add(action => 'lock_page');
    $registry->add(action => 'unlock_page');
    $registry->add(action => 'edit_content');
    $registry->add(action => 'edit_start');
    $registry->add(action => 'edit_cancel');
    $registry->add(action => 'edit_check');
}

sub edit_save {
    my $self = shift;
    $self->save;
}

sub _validate_pagename_length {
    my $self = shift;
    my $page_name = shift;

    my $id = Socialtext::String::title_to_id($page_name);

    if ( Socialtext::String::MAX_PAGE_ID_LEN < length $id ) {
        my $message = loc("Page title is too long after URL encoding");
        data_validation_error errors => [$message];
    }
    if ( length $id == 0 ) {
        my $message = loc("Page title missing");
        data_validation_error errors => [$message];
    }
}

sub _set_page_lock {
    my $self  = shift;
    my $state = shift;

    my $page_name = $self->cgi->page_name;

    $self->_validate_pagename_length( $page_name );

    my $page = $self->hub->pages->new_from_name($page_name);

    return $self->to_display($page)
        unless $self->hub->checker->check_permission('lock')
            && $self->hub->current_workspace->allows_page_locking;

    $page->update_lock_status( $state );
    return $self->to_display($page)
}

sub lock_page {
    my $self      = shift;

    return $self->_set_page_lock(1);
}

sub unlock_page {
    my $self      = shift;

    return $self->_set_page_lock(0);
}

sub edit_content {
    my $self = shift;
    my $page_name = $self->cgi->page_name;
    my $content   = $self->cgi->page_body;

    $self->_validate_pagename_length($page_name);

    my $page = $self->hub->pages->new_from_name($page_name);
    return $self->to_display($page)
        unless $self->hub->checker->check_permission('edit');

    $page->load;

    return $self->_page_locked_screen($page)
        unless $self->hub->checker->can_modify_locked($page);

    my $append_mode = $self->cgi->append_mode || '';

    if ($self->_there_is_an_edit_contention($page, $self->cgi->revision_id)) {
        if ($append_mode eq '') {
            $self->_record_edit_contention($page);
            return $self->_edit_contention_screen($page);
        }
    }

    my $metadata = $page->metadata;

    my $edit_summary = Socialtext::String::trim($self->cgi->edit_summary || '');

    $metadata->loaded(1);
    $metadata->update( user => $self->hub->current_user );
    $metadata->Subject($page_name);
    $metadata->Type($self->cgi->page_type);
    $metadata->RevisionSummary($edit_summary);

    $page->name($page_name);
    if ($append_mode eq 'bottom') {
        $page->append($content);
    }
    elsif ($append_mode eq 'top') {
        $page->prepend($content);
    }
    else {
        $page->content($content);
    }

    if ( my @tags = $self->cgi->add_tag ) {
        foreach my $tag ( @tags ) {
            $metadata->add_category($tag);
        }
    }

    my %event = (
        event_class => 'page',
        action => 'edit_save',
        page => $page,
    );

    my $signal = $page->store(
        user => $self->hub->current_user,
        signal_edit_summary => scalar($self->cgi->signal_edit_summary),
        edit_summary => $edit_summary,
    );

    if ($signal) {
        $event{signal} = $signal->signal_id;
    } 

    Socialtext::Events->Record(\%event);

    # Move attachments uploaded to 'Untitled Page'/'Untitled Spreadsheet' to the actual page
    my @attach = $self->cgi->attachment;
    for my $a (@attach) {
        my ($id, $page_id) = split ':', $a;

        my $source = $self->hub->attachments->new_attachment(
            id => $id,
            page_id => $page_id
        )->load;

        my $target = $self->hub->attachments->new_attachment(
            id => $source->id,
            filename => $source->filename,
        );

        # move attachments that were uploaded to the incorrect page
        if ($page_id ne $self->hub->pages->current->id) {
            my $target_dir = $self->hub->attachments->plugin_directory;
            $target->copy($source, $target, $target_dir);
            $target->store(
                user => $self->hub->current_user,
                dir => $target_dir,
            );
            $source->purge($source->page);
        }

        # Remove the temporary flag from the new file
        $target->make_permanent(user => $self->hub->current_user);
    }

    return $self->to_display($page);
}

sub edit {
    my $self = shift;

    my $page_name = $self->cgi->page_name;
    $self->_validate_pagename_length($page_name);

    return $self->hub->display->display(1);
}

sub save {
    my $self = shift;
    my $original_page_id = $self->cgi->original_page_id
        or
        Socialtext::Exception::DataValidation->throw("no original page id");
    my $page = $self->hub->pages->new_page($original_page_id);

    return $self->to_display($page)
        unless $self->hub->checker->check_permission('edit');

    $page->load;

    return $self->_page_locked_screen($page)
        unless $self->hub->checker->can_modify_locked($page);

    if ($self->_there_is_an_edit_contention($page, $self->cgi->revision_id)) {
        $self->_record_edit_contention($page);
        return $self->_edit_contention_screen($page);
    }

    my $subject = $self->cgi->subject || $self->cgi->page_title;
    # Err, this is an unreachable condition since we default to using
    # the title as stored in a hidden form variable.
    unless ( defined $subject && length $subject ) {
        Socialtext::Exception::DataValidation->throw(
            errors => [loc('A page must have a title to be saved.')] );
    }

    my $body = $self->cgi->page_body;
    unless ( defined $body && length $body ) {
        Socialtext::Exception::DataValidation->throw(
            errors => [loc('A page must have a body to be saved.')] );
    }

    my $edit_summary
        = Socialtext::String::trim($self->cgi->edit_summary || '');

    my @categories =
      sort keys %{+{map {($_, 1)} split /[\n\r]+/, $self->cgi->header}};
    my @tags = $self->cgi->add_tag;
    push @categories, @tags;
    $page->update(
        content => $body,
        original_page_id => $self->cgi->original_page_id,
        revision         => $self->cgi->revision || 0,
        categories       => \@categories,
        subject          => $subject,
        user             => $self->hub->current_user,
        edit_summary     => $edit_summary,
        signal_edit_summary => 1,
    );
    Socialtext::Events->Record({
        event_class => 'page',
        action => 'edit_save',
        page => $page,
    });
    return $self->to_display($page);
}

sub _record_edit_contention {
    my $self = shift;
    my $page = shift;

    # record the event.
    Socialtext::Events->Record({
        event_class => 'page',
        action => 'edit_contention',
        page => $page,
    });

    # log it.
    my $user = $self->hub->current_user;
    my $ws   = $self->hub->current_workspace;
    st_log->info(
        'EDIT_CONTENTION,PAGE,edit_contention,'
        . 'workspace:' . $ws->name . '(' . $ws->workspace_id . '),'
        . 'user:' . $user->email_address . '(' . $user->user_id . '),'
        . 'page:' . $page->id
    );
}

sub _page_locked_screen {
    my $self = shift;
    my $page = shift;

    $self->screen_template('view/page_locked');
    return $self->render_screen(
        page => $page,
        page_body => $self->html_escape($self->cgi->page_body),
        display_title => $page->title,
        header_display_title => $page->title,
    );
}

# Build the edit contention screen
# .RETURN. The HTML for the screen
sub _edit_contention_screen {
    my $self = shift;
    my $page = shift;

    $self->screen_template('view/edit_contention');
    return $self->render_screen(
        page => $page,
        page_body => $self->html_escape($self->cgi->page_body),
        display_title => $page->title,
        header_display_title => $page->title,
        attachment_count => scalar $self->hub->attachments->all,
        revision_count => $self->hub->pages->current->metadata->Revision,
    );
}

sub _there_is_an_edit_contention {
    my $self = shift;
    my $page = shift;
    my $original_revision = shift;

    return 0 unless defined $original_revision;
    return 0 unless $page->exists;
    return 0 if $page->deleted;
    return 0 if ($page->revision_id eq $original_revision);

    # If the revision ID we got wasn't a valid page revision,
    # there's contention.
    my @revisions = $page->all_revision_ids;
    if (!grep (/^$original_revision$/, @revisions)) {
        return 1;
    }
    # Since the revision is different, pull the old page and check contents against the current page
    my $original_page = $self->hub->pages->new_page($page->id)->load_revision($original_revision);
    return ($original_page->content ne $page->content);
}

sub to_display {
    my $self = shift;
    my $page = shift;
    my $edit_mode = shift || 0;

    my $path = Socialtext::WeblogPlugin->compute_redirection_destination(
        page          => $page,
        caller_action => $self->cgi->caller_action,
    );

    if ($edit_mode) {
        $self->redirect("$path#edit");
    } else {
        $self->redirect($path);
    }
}

sub edit_start  { _add_edit_event(shift, 'edit_start' ) }
sub edit_cancel { _add_edit_event(shift, 'edit_cancel') }

sub _add_edit_event {
    my $self        = shift;
    my $action_name = shift;
    my $page_name   = $self->cgi->page_name;

    my $page = $self->hub->pages->new_from_name($page_name);
    return '' unless $self->hub->checker->check_permission('edit');
    return '' unless $self->hub->checker->can_modify_locked($page);
    return unless $page->active;

    eval {
        Socialtext::Events->Record({
            event_class => 'page',
            action => $action_name,
            page => $page,
        });
    };
    warn $@ if $@;
    return '';
}

sub edit_check {
    my $self        = shift;
    my $page_name   = $self->cgi->page_name;

    my $page = $self->hub->pages->new_from_name($page_name);

    return encode_json(
        $page->edit_in_progress || {}
    );
}

package Socialtext::Edit::CGI;

use base 'Socialtext::CGI';
use Socialtext::CGI qw( cgi );

cgi 'Button';
cgi 'append_mode';
cgi 'caller_action';
cgi 'category';
cgi 'header';
cgi 'revision_id';
cgi 'page_type';
cgi 'original_page_id';
cgi 'page_body';
cgi 'revision';
cgi 'subject';
cgi 'summary';
cgi 'type';
cgi 'page_title';
cgi 'add_tag';
cgi 'attachment';
cgi 'edit_summary';
cgi 'signal_edit_summary';

1;
