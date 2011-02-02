package Socialtext::Page;
# @COPYRIGHT@
use Moose;

use Socialtext::AppConfig;
use Socialtext::EmailSender::Factory;
use Socialtext::Encode;
use Socialtext::Events;
use Socialtext::File;
use Socialtext::Formatter::AbsoluteLinkDictionary;
use Socialtext::Formatter::Parser;
use Socialtext::Formatter::Viewer;
use Socialtext::JobCreator;
use Socialtext::Log qw( st_log );
use Socialtext::Log qw/st_log/;
use Socialtext::PageMeta;
use Socialtext::Paths;
use Socialtext::Permission 'ST_READ_PERM';
use Socialtext::SQL qw/:exec :txn :time/;
use Socialtext::SQL::Builder qw/sql_insert_many/;
use Socialtext::Search::AbstractFactory;
use Socialtext::String;
use Socialtext::Timer qw/time_scope/;
use Socialtext::Validate qw(validate :types SCALAR ARRAYREF BOOLEAN POSITIVE_INT_TYPE USER_TYPE UNDEF);
use Socialtext::WikiText::Emitter::SearchSnippets;
use Socialtext::WikiText::Parser;
use Socialtext::l10n qw(loc system_locale);

use Digest::SHA1 'sha1_hex';
use Carp ();
use Class::Field qw( field const );
use Cwd ();
use DateTime;
use DateTime::Duration;
use DateTime::Format::Strptime;
use Date::Parse qw/str2time/;
use Email::Valid;
use File::Path;
use Readonly;
use Text::Autoformat;
use Time::Duration::Object;

Readonly my $SYSTEM_EMAIL_ADDRESS       => 'noreply@socialtext.com';
Readonly my $IS_RECENTLY_MODIFIED_LIMIT => 60 * 60; # one hour
Readonly my $WIKITEXT_TYPE              => 'text/x.socialtext-wiki';
Readonly my $HTML_TYPE                  => 'text/html';

my $REFERENCE_TIME = undef;
our $CACHING_DEBUG = 0;
our $DISABLE_CACHING = 0;

field 'id';
sub class_id { 'page' }
field full_uri =>
      -init => '$self->hub->current_workspace->uri . $self->uri';
field database_directory => -init =>
    'Socialtext::Paths::page_data_directory( $self->hub->current_workspace->name )';

sub _MAX_PAGE_ID_LENGTH () {
    return 255;
}

sub new {
    my $class = shift;
    my %p = @_;

    return if $p{id} && length $p{id} > _MAX_PAGE_ID_LENGTH;

    Socialtext::Timer->Continue('page_new');
    my $self = $class->SUPER::new(%p);
    $self->metadata($self->new_metadata($self->id));
    Socialtext::Timer->Pause('page_new');
    return $self;
}

sub new_from_row {
    my $class = shift;
    my $db_row = shift;
    bless $db_row, $class;
    $db_row->{last_edit_time} = delete $db_row->{last_edit_time_utc};
    $db_row->{create_time} = delete $db_row->{create_time_utc};
    return $db_row;
}

sub last_edited_by {
    my $self = shift;
    return $self->{last_editor}
        ||= Socialtext::User->new( user_id => $self->{last_editor_id} );
}

sub creator {
    my $self = shift;
    return $self->{creator}
        ||= Socialtext::User->new( user_id => $self->{creator_id} );
}

sub tags { Carp::croak "finish me!" }

*tags_sorted = *categories_sorted;
sub categories_sorted {
    my $self = shift;
    return sort {lc($a) cmp lc($b)} @{$self->tags};
}


sub full_uri {
    my $self = shift;
    return Socialtext::URI::uri(
        path => "$self->{workspace_name}/",
    ) . "$SCRIPT_NAME?$self->{page_id}";
}

sub modified_time {
    my $self = shift;
    return $self->{modified_time} ||= 
        DateTime::Format::Pg->parse_timestamptz($self->last_edit_time)->epoch;
}

sub createtime_for_user {
    my $self = shift;
    my $t = $self->{create_time};
    if ($self->{hub}) {
        $t = $self->{hub}->timezone->date_local($t);
    }
    return $t;
}

sub datetime_for_user {
    my $self = shift;
    my $datetime = $self->{last_edit_time};
    if ($self->{hub}) {
        $datetime = $self->{hub}->timezone->date_local($datetime);
    }
    return $datetime;
}

sub revision_id {
    my $self = shift;
    if (@_) {
        $self->{revision_id} = shift;
        return $self->{revision_id};
    }
    return $self->assert_revision_id;
}

# XXX split this into a getter and setter to more
# accurately measure how often it is called as a
# setter. In a fake-request run of 50, this is called 1100
# times, which is, uh, high. When disk is loaded, it eats
# a lot of real time.
sub assert_revision_id {
    my $self = shift;
    my $revision_id = $self->{revision_id};
    return $revision_id if $revision_id;
    return '' unless my $index_file = $self->_get_index_file;

    $revision_id = readlink $index_file;
    $revision_id =~ s/(?:.*\/)?(.*)\.txt$/$1/
      or die "$revision_id is bad file name";
    $self->revision_id($revision_id);
}

sub name {
    my $self = shift;
    $self->{name} = shift if @_;
    if ( !defined( $self->{name} ) ) {
        $self->{name} = $self->uri_unescape($self->id);
    }
    return $self->{name};
}

sub revision_count {
    my $self = shift;
    return scalar $self->all_revision_ids();
}

sub creator {
    my $self = shift;
    return $self->original_revision->last_edited_by
        || Socialtext::User->SystemUser;
}

sub create {
    my $self = shift;
    my %args = validate(
        @_,
        {
            title      => SCALAR_TYPE,
            content    => SCALAR_TYPE,
            date       => { can => [qw(strftime)], default => undef },
            categories => { type => ARRAYREF, default => [] },
            creator    => USER_TYPE,
        }
    );

    # FIXME: it's possible for this call to return undef and
    # we dont' trap it.
    my $page = $self->hub->pages->new_from_name($args{title});
    $page->content($args{content});
    $page->metadata->Subject($args{title});
    $page->metadata->Category($args{categories});
    $page->metadata->update( user => $args{creator} );

    # hard_set_date does its own store
    if ($args{date}) {
        $page->hard_set_date( $args{date}, $args{creator} );
    }
    else {
        $page->store( user => $args{creator} );
    }

    return $page;
}

Readonly my $SignalCommentLength => 250;
Readonly my $SignalEditLength => 140;
sub _signal_edit_summary {
    my ($self, $user, $edit_summary, $to_network, $is_comment) = @_;
    my $signals = $self->hub->pluggable->plugin_class('signals');
    return unless $signals;
    return unless $user->can_use_plugin('signals');

    my $workspace = $self->hub->current_workspace;
    $user ||= $self->hub->current_user;

    # Trim trailing whitespaces first
    $edit_summary =~ s/\s+$//;

    # If edit summary starts with a symbol (e.g. #tag or {wafl}), prepend a space
    # so the syntax won't be blocked by the leading double-quote.
    $edit_summary =~ s/^([^\s\w])/ $1/;

    $edit_summary = Socialtext::String::word_truncate($edit_summary, ($is_comment ? $SignalCommentLength : $SignalEditLength));
    my $page_link = sprintf "{link: %s [%s]}", $workspace->name, $self->title;
    my $body = $edit_summary
        ? ($is_comment
            ? loc('"[_1]" (commented on [_2] in [_3])', $edit_summary, $page_link, $workspace->title)
            : loc('"[_1]" (edited [_2] in [_3])', $edit_summary, $page_link, $workspace->title))
        : loc('wants you to know about an edit of [_1] in [_2]', $page_link, $workspace->title);

    my %params = (
        user  => $user,
        body  => $body,
        topic => {
            page_id      => $self->id,
            workspace_id => $workspace->workspace_id,
        },
        annotations => [
            { icon => { title => ($is_comment ? 'comment' : 'edit') } }
        ],
    );

    if ($to_network and $to_network =~ /^(group|account)-(\d+)$/) {
        $params{"$1_ids"} = [ $2 ];
    }
    else {
        $params{account_ids} = [ $workspace->account_id ];
    }

    my $signal = $signals->Send(\%params);
    if ($signal->is_edit_summary) {
        return $signal;
    }
    return;
}

sub update_from_remote {
    my $self = shift;
    my %p = @_;

    my $content     = $self->utf8_decode($p{content});
    my $revision_id = $self->utf8_decode($p{revision_id});
    my $revision    = $self->utf8_decode($p{revision});
    my $subject     = $self->utf8_decode($p{subject});
    my $edit_summary = $self->utf8_decode($p{edit_summary});
    my $tags        = $p{tags};
    my $type        = $p{type};
    my $locked      = exists($p{locked}) ? $p{locked} : $self->locked;

    if ($tags) {
        $tags = [ map { $self->utf8_decode($_) } @$tags ];
    }
    else {
        $tags = $self->metadata->Category;    # preserve categories
    }

    my $user = $self->hub->current_user;

    unless ($self->hub->checker->check_permission('admin_workspace')) {
        delete $p{date};
        delete $p{from};
    }

    # We've already check for permission to do this
    if ( $p{from} ) {
        $user = Socialtext::User->Resolve( $p{from} );
        $user ||= Socialtext::User->create(
            email_address => $p{from},
            username      => $p{from}
        );
    }
    die "A valid user is required to update a page\n" unless $user;

    if (!$self->hub->checker->can_modify_locked($self)) {
        my $ws = $self->hub->current_workspace;
        st_log->info(
            'LOCK_EDIT,PAGE,lock_edit,'
            . 'workspace:' . $ws->name . '(' . $ws->workspace_id . '),'
            . 'user:' . $user->email_address . '(' . $user->user_id . '),'
            . 'page:' . $self->id
        );
        die "Page is locked and cannot be edited\n";
    }

    $revision_id  ||= $self->revision_id;
    $revision     ||= $self->metadata->Revision || 0;
    $subject      ||= $self->title,
    $type         ||= $self->metadata->Type,
    $edit_summary ||= '';

    $self->load;
    if ( $self->revision_id ne $revision_id ) {
        Socialtext::Events->Record({
            event_class => 'page',
            action => 'edit_contention',
            page => $self,
        });
 
        my $ws = $self->hub->current_workspace;

        st_log->info(
            'EDIT_CONTENTION,PAGE,edit_contention,'
            . 'workspace:' . $ws->name . '(' . $ws->workspace_id . '),'
            . 'user:' . $user->email_address . '(' . $user->user_id . '),'
            . 'page:' . $self->id
        );

        die "Contention: page has been updated since retrieved\n";
    }

    $self->update(
        original_page_id => $self->id,
        content          => $content,
        revision         => $revision,
        subject          => $subject,
        categories       => $tags,
        user             => $user,
        edit_summary     => $edit_summary,
        locked           => $locked,
        type             => $type,
        $p{date} ? (date => $p{date}) : (),
        # don't signal-this-edit via update() so we can tie it to the event
    );

    # XXX: record a lock/unlock event.

    my %event = (
        event_class => 'page',
        action => 'edit_save',
        page => $self,
    );

    if ($p{signal_edit_summary}) {
        $event{signal} = $self->_signal_edit_summary(
            $user, $edit_summary, $p{signal_edit_to_network});
    }

    Socialtext::Events->Record(\%event);
    return; 
}

sub update_lock_status {
    my $self   = shift;
    my $status = shift;
    my $summary;
    my $action;

    if ( $status ) {
        $summary = loc('Locking page.');
        $action  = 'lock_page';
    }
    else {
        $summary = loc('Unlocking page.');
        $action  = 'unlock_page';
    }

    eval {
        $self->update(
            subject          => $self->metadata->Subject,
            revision         => $self->metadata->Revision,
            locked           => $status,
            user             => $self->hub->current_user,
            content          => $self->content,
            original_page_id => $self->id,
            type             => $self->metadata->Type,
            edit_summary     => $summary,
        );
    };
    if ($@) {
        die "$@";
    }

    Socialtext::Events->Record({
        event_class => 'page',
        action => $action,
        page => $self,
    });
}

{
    Readonly my $spec => {
        content          => { type => SCALAR, default => '' },
        original_page_id => SCALAR_TYPE,
        revision         => { type => SCALAR,   regex   => qr/^\d+$/ },
        type             => { type => SCALAR,   regex   => qr/^(?:wiki|spreadsheet)$/, default => 'wiki' },
        categories       => { type => ARRAYREF, default => [] },
        subject             => SCALAR_TYPE,
        user                => USER_TYPE,
        date                => { can => [qw(strftime)], default => undef },
        edit_summary        => { type => SCALAR, default => '' },
        signal_edit_summary => { type => SCALAR, default => undef },
        signal_edit_summary_from_comment => { type => SCALAR, default => undef },
        signal_edit_to_network => { type => SCALAR, default => undef },
        locked              => { type => SCALAR, default => undef },
    };
    sub update {
        my $self = shift;
        my %args = validate( @_, $spec );
        # XXX validate these args

        # explicitly set both id and name to predictable things _now_
        $self->id(Socialtext::String::title_to_id($args{subject}));
        $self->name($args{subject});

        my $revision
            = $self->id eq $args{original_page_id} ? $args{revision} : 0;


        my $metadata = $self->metadata;
        $metadata->Subject($args{subject});
        $metadata->Revision($revision);
        $metadata->Received(undef);
        $metadata->MessageID('');
        $metadata->RevisionSummary(Socialtext::String::trim($args{edit_summary}));
        if (defined($args{locked})) {
            $metadata->Locked($args{locked});
        }
        if (defined($args{type})) {
            $metadata->Type($args{type});
        }
        $metadata->loaded(1);
        foreach (@{$args{categories}}) {
            $metadata->add_category($_);
        }

        $self->content($args{content});

        $metadata->update( user => $args{user} );
        # hard_set_date does its own store
        if ($args{date}) {
            $self->hard_set_date( $args{date}, $args{user} );
        }
        else {
            $self->store( user => $args{user} );
        }

        if ($args{signal_edit_summary}) {
            $self->_signal_edit_summary($args{user}, $args{edit_summary}, $args{signal_edit_to_network});
        }
    }
}

sub hash_representation {
    my $self = shift;

    # The name, uri, and full_uri are totally botched for pages which never
    # existed.  For pages that never existed the various methods do "smart"
    # things and return values we don't want.  We can't just change the
    # original methods b/c they're part of the bedrock of our app and would
    # have far reaching changes, so we do it here.
    my ( $name, $uri, $page_uri );
    if ( $self->exists ) {
        $name     = $self->metadata->Subject;
        $uri      = $self->uri;
        $page_uri = $self->full_uri;
    }
    else {
        $name     = $self->name;
        $uri      = $self->id;
        $page_uri = $self->hub->current_workspace->uri
            . Socialtext::AppConfig->script_name . "?"
            . $self->id;
    }

    my $from = $self->metadata->From;
    my $user = Socialtext::User->new(email_address => $from);
    my $masked_email = $user
        ? $user->masked_email_address(
            user => $self->hub->current_user,
            workspace => $self->hub->current_workspace,
        ) : $from;

    return +{
        edit_summary => $self->edit_summary,
        last_edit_time => $self->metadata->Date,
        last_editor    => $masked_email,
        locked => $self->locked,
        modified_time  => $self->modified_time,
        name     => $name,
        page_id  => $self->id,
        page_uri       => $page_uri,
        revision_count => $self->revision_count,
        revision_id    => $self->revision_id,
        tags           => $self->metadata->Category,
        type => $self->metadata->Type,
        uri      => $uri,
        workspace_name => $self->hub->current_workspace->name,
        workspace_title => $self->hub->current_workspace->title,
    };
}

# This is called by Socialtext::Query::Plugin::push_result
# to create a row suitable for display in a listview.
our $No_result_times = 0;
sub to_result {
    my $self = shift;

    Socialtext::Timer->Continue('model_to_result');
    my $user = $self->last_edited_by;

    my $result = {
        From     => $user->email_address,
        username => $user->username,
        Date     => "$self->{last_edit_time} GMT",
        ($No_result_times ? ()
            : (DateLocal => $self->datetime_for_user)),
        Subject  => $self->{name},
        Revision => $self->{current_revision_num},
        Summary  => $self->{summary},
        Type     => $self->{page_type},
        page_id  => $self->{page_id},
        create_time => $self->{create_time},
        ($No_result_times ? () 
            : (create_time_local => $self->createtime_for_user)),
        creator => $self->creator->username,
        page_uri => $self->uri,
        revision_count => $self->{revision_count},
        $self->{hub} && !$self->hub->current_workspace->workspace_id ? (
            workspace_title => $self->workspace->title,
            workspace_name => $self->workspace->name,
        ) : (),
        is_spreadsheet => $self->is_spreadsheet,
        edit_summary => $self->{edit_summary},
        Locked     => $self->{locked},
        ($No_result_times ? (page => $self) : ()),
    };
    Socialtext::Timer->Pause('model_to_result');

    return $result;
}


sub get_headers {
    my $self = shift;
    return $self->get_units(
        'hx' => sub {
            return +{text => $_[0]->get_text, level => $_[0]->level}
        },
    );
}


sub get_sections {
    my $self = shift;
    return $self->get_units(
        'hx' => sub {
            return +{text => $_[0]->get_text};
        },
        'wafl_phrase' => sub {
            return unless $_[0]->method eq 'section';
            return +{text => $_[0]->arguments};
        },
    )
}

sub title {
    my $self = shift;
    if ( @_ ) {
        $self->{title} = shift;
    }
    if ( !defined $self->{title} ) {
        $self->{title} = $self->metadata->Subject || $self->hub->cgi->page_name;
    }
    return $self->{title};
}

sub prepend {
    my $self = shift;
    my $new_content = shift;

    if (defined($self->content) && $self->content) {
        $self->content("$new_content\n---\n" . $self->content);
    } else {
        $self->content($new_content);
    }
}

sub append {
    my $self = shift;
    my $new_content = shift;

    if (defined($self->content) && $self->content) {
        $self->content($self->content . "\n---\n$new_content");
    }
    else {
        $self->content($new_content);
    }
}

sub uri {
    my $self = shift;
    return $self->{uri} if defined $self->{uri};
    $self->{uri} = $self->exists
    ? $self->id
    : $self->hub->pages->title_to_uri($self->title);
}

sub add_tags {
    my $self = shift;
    my @tags  = grep { length } @_;
    return unless @tags;

    if ( $self->hub->checker->check_permission('edit') ) {
        my $meta = $self->metadata;
        my %tags_added;
        foreach my $tag (@tags) {
            my $added = $meta->add_category($tag);
            $tags_added{$tag} = 1;
        }
        $self->metadata->update( user => $self->hub->current_user );
        $self->metadata->RevisionSummary('');
        $self->store( user => $self->hub->current_user );
        foreach my $tag (keys %tags_added) {
            Socialtext::Events->Record({
                event_class => 'page',
                action => 'tag_add',
                page => $self,
                tag_name => $tag,
            });
        }
    }
}

sub delete_tag {
    my $self = shift;
    my $tag = shift;

    if ( $self->hub->checker->check_permission('edit') ) {
        $self->metadata->delete_category($tag);
        $self->metadata->RevisionSummary('');
        $self->metadata->update( user => $self->hub->current_user );
        $self->store( user => $self->hub->current_user );
    }
}


sub has_tag {
    my $self = shift;
    my $tag = shift;

    return $self->metadata->has_category($tag);
}


sub add_comment {
    my $self     = shift;
    my $wikitext = shift;
    my $signal_edit_to_network = shift;
    my $user = $self->hub->current_user;

    if (!$self->hub->checker->can_modify_locked($self)) {
        my $ws = $self->hub->current_workspace;
        st_log->info(
            'LOCK_EDIT,PAGE,lock_edit,'
            . 'workspace:' . $ws->name . '(' . $ws->workspace_id . '),'
            . 'user:' . $user->email_address . '(' . $user->user_id . '),'
            . 'page:' . $self->id
        );
        die "Page is locked and cannot be edited\n";
    }

    my $timer = Socialtext::Timer->new;

    # Clean it up.
    $wikitext =~ s/\s*\z/\n/;

    $self->content( $self->content
            . "\n---\n"
            . Socialtext::Encode::ensure_is_utf8($wikitext)
            . $self->_comment_attribution );

    $self->metadata->update( user => $self->hub->current_user );

    $self->metadata->RevisionSummary(loc('(comment)'));
    my $signal = $self->store(
        user => $user,
        $signal_edit_to_network ? (
            edit_summary => $wikitext,
            signal_edit_summary_from_comment => 1,
            signal_edit_to_network => $signal_edit_to_network,
        ) : ()
    );

    # Truncate the comment to $SignalCommentLength chars if we're sending this
    # comment as a signal.  Otherwise use the normal 350-char excerpt.
    my $summary = $signal
        ? Socialtext::String::word_truncate($wikitext, $SignalCommentLength)
        : $self->preview_text($wikitext);

    my %event = (
        event_class => 'page',
        action => 'comment',
        page => $self,
        summary => $summary,
    );
    if ($signal) {
        $event{signal} = $signal;
    }

    Socialtext::Events->Record(\%event);
    return;
}

sub _comment_attribution {
    my $self = shift;

    if (    my $email    = $self->hub->current_user->email_address
        and my $utc_date = $self->metadata->get_date ) {
        return "\n_".loc("contributed by {user: [_1]} on {date: [_2]}", $email, $utc_date)."_\n";
    }

    return '';
}

sub restored {
    return ( defined $_[0]->{_restored} ) ? 1 : 0;
}

sub is_untitled {
    my $self = shift;

    if ($self->id eq 'untitled_page') {
        return 'Untitled Page';
    }
    elsif ($self->id eq 'untitled_spreadsheet') {
        return 'Untitled Spreadsheet';
    }

    return '';
}

sub store {
    my $self = shift;
    my %p = @_;
    Carp::confess('no user given to Socialtext::Page->store')
        unless $p{user};

    # Fix for {bz 2099} -- guard against storing an "Untitled Page".
    if (my $display_name = $self->is_untitled) {
        die loc('"[_1]" is a reserved name. Please use a different name.', $display_name);
    }

    # Make sure we have minimal metadata needed to store a page
    $self->metadata->update( user => $p{user} )
        unless $self->metadata->Revision;

    # XXX Why are we accessing _MAX_PAGE_ID_LENGTH, which implies to me
    # a very private piece of data.
    if (Socialtext::String::MAX_PAGE_ID_LEN < length($self->id)) {
        my $message = loc("Page title is too long after URL encoding");
        Socialtext::Exception::DataValidation->throw( errors => [ $message ] );
    }

    $self->{_restored} = 1 if $self->deleted;

    my $original_categories =
      ref($self)->new(hub => $self->hub, id => $self->id)->metadata->Category;

    my $metadata = $self->{metadata}
      or die "No metadata for content object";
    my $body = $self->content;
    if (length $body) {
        $body =~ s/\r//g;
        $body =~ s/\{now\}/$self->formatted_date/egi;
        $body =~ s/\n*\z/\n/;
        $metadata->Control('');
        $metadata->Summary( $self->preview_text( $body ) );
        $self->content($body);
    }
    else {
        $metadata->Control('Deleted');
    }

    $self->write_file();
    $self->_perform_store_actions();

    $self->_log_edit_summary($p{user}) if $self->metadata->RevisionSummary;

    if ($p{signal_edit_summary_from_comment}) {
        return $self->_signal_edit_summary($p{user}, $p{edit_summary}, $p{signal_edit_to_network}, 'comment');
    }
    elsif ($p{signal_edit_summary}) {
        return $self->_signal_edit_summary($p{user}, $p{edit_summary}, $p{signal_edit_to_network});
    }

    return;
}

sub _log_edit_summary {
    my $self = shift;
    my $user = shift || $self->hub->current_user;
    my $ws   = $self->hub->current_workspace;

    st_log->info(
        'CREATE,EDIT_SUMMARY,edit_summary,'
        . 'workspace:' . $ws->name . '(' . $ws->workspace_id . '),'
        . 'user:' . $user->email_address . '(' . $user->user_id . '),'
        . 'page:' . $self->id
    );
}

sub _perform_store_actions {
    my $self = shift;
    $self->update_db_metadata();
    $self->hub->backlinks->update($self);
    Socialtext::JobCreator->index_page($self);
    Socialtext::JobCreator->send_page_notifications($self);
    $self->_ensure_page_assets();
    $self->_log_page_action();
    $self->_cache_html();

    $self->hub->pluggable->hook( 'nlw.page.update',
        [$self, workspace => $self->hub->current_workspace],
    );
}

sub _ensure_page_assets {
    my $self = shift;

    return unless $self->revision_count == 1;

    require Socialtext::Signal::Topic;
    Socialtext::Signal::Topic::Page->EnsureAssetsFor(
        page_id => $self->id,
        workspace_id => $self->hub->current_workspace->workspace_id,
    );
}

sub update_db_metadata {
    my $self = shift;
    sql_txn { $self->_do_update_db_metadata() };
}

sub _do_update_db_metadata {
    my $self = shift;
    my $hash = $self->hash_representation;
    my $wksp_id = $self->hub->current_workspace->workspace_id;
    my $pg_id = $hash->{page_id};

    my $sth = sql_execute(
        q{SELECT creator_id, create_time FROM page
            WHERE workspace_id = ? AND page_id = ? FOR UPDATE},
        $wksp_id, $pg_id,
    );
    my $rows = $sth->fetchall_arrayref();
    my ($creator_id, $create_time);
    my $exists = 0;
    if (@$rows) {
        $exists = 1;
        $creator_id = $rows->[0][0];
        $create_time = $rows->[0][1];
    }
    else {
        my $orig_page = $self->original_revision;
        $creator_id = $orig_page->last_edited_by->user_id;
        $create_time = $orig_page->metadata->Date;
    }

    my @args = (
        $hash->{name},
        $self->last_edited_by->user_id, $hash->{last_edit_time},
        $creator_id, $create_time,
        $hash->{revision_id}, $self->metadata->Revision,
        $hash->{revision_count},
        $hash->{type}, $self->deleted ? '1' : '0', 
        $self->metadata->Summary,
        $self->metadata->RevisionSummary,
        $self->metadata->Locked ? '1' : '0',
        $wksp_id, $pg_id
    );
    my $insert_or_update;
    if ($exists) {
        $insert_or_update = <<'UPDSQL';
            UPDATE page SET
                name = ?,
                last_editor_id = ?, last_edit_time = ?,
                creator_id = ?, create_time = ?,
                current_revision_id = ?, current_revision_num = ?,
                revision_count = ?,
                page_type = ?, deleted = ?, summary = ?, edit_summary = ?, locked = ?
            WHERE
                workspace_id = ? AND page_id = ?
UPDSQL

        # we don't reference the page_tag table, so it's safe to nuke 'em
        sql_execute('DELETE FROM page_tag 
                     WHERE workspace_id = ? AND page_id = ?',
                    $wksp_id, $pg_id);
    }
    else {
        $insert_or_update = <<'INSSQL';
            INSERT INTO page (
                name, 
                last_editor_id, last_edit_time, 
                creator_id, create_time,
                current_revision_id, current_revision_num, 
                revision_count,
                page_type, deleted, summary, edit_summary, locked,
                workspace_id, page_id
            )
            VALUES (
                ?,
                ?, ?::timestamptz,
                ?, ?::timestamptz,
                ?, ?, 
                ?, 
                ?, ?, ?, ?, ?,
                ?, ?
            )
INSSQL
    }
    sql_execute($insert_or_update, @args);

    my $tags = $self->metadata->Category;
    if (@$tags) {
        sql_insert_many( 
            page_tag => [qw/workspace_id page_id tag/],
            [ map { [$wksp_id, $pg_id, $_] } @$tags ],
        );
    }
}

sub is_system_page {
    my $self = shift;

    my $from = $self->metadata->From;
    return (
               $from eq $SYSTEM_EMAIL_ADDRESS
            or $from eq Socialtext::User->SystemUser()->email_address()
    );
}

sub content {
    my $self = shift;
    return $self->{content} = shift if @_;
    return $self->{content} if defined $self->{content};
    $self->load_content;
    return $self->{content};
}

sub content_as_type {
    my $self = shift;
    my %p    = @_;

    my $type = $p{type} || $WIKITEXT_TYPE;

    my $content;

    if ( $type eq $HTML_TYPE ) {
        return $self->_content_as_html( $p{link_dictionary}, $p{no_cache} );
    }
    elsif ( $type eq $WIKITEXT_TYPE ) {
        return $self->content();
    }
    else {
        Socialtext::Exception->throw("unknown content type");
    }
}

sub _content_as_html {
    my $self            = shift;
    my $link_dictionary = shift;
    my $no_cache        = shift;

    if ( defined $link_dictionary ) {
        my $link_dictionary_name = 'Socialtext::Formatter::'
            . $link_dictionary
            . 'LinkDictionary';
        my $link_dictionary;
        eval {
            eval "require $link_dictionary_name";
            $link_dictionary = $link_dictionary_name->new();
        };
        if ($@) {
            my $message
                = "Unable to create link dictionary $link_dictionary_name: $@";
            Socialtext::Exception->throw($message);
        }
        $self->hub->viewer->link_dictionary($link_dictionary);
    }

    # REVIEW: the args to to_html are to help make caching work
    if ($no_cache) {
        return $self->to_html;
    }
    else {
        return $self->to_html( $self->content, $self );
    }
}

sub doctor_links_with_prefix {
    my $self = shift;
    my $prefix = shift;
    my $new_content = $self->content();
    my $link_class = 'Socialtext::Formatter::FreeLink';
    my $start = $link_class->pattern_start;
    my $end = $link_class->pattern_end;
    $new_content =~ s/{ (link:\s+\S+\s) \[ ([^\]]+) \] }/{$1\{$2}}/xg;
    # $start contains grouping syntax so we must skip $2
    $new_content =~ s/($start)((?!$prefix).+?)($end)/$1$prefix$3$4/g;
    $new_content =~ s/{ (link:\s+\S+\s) { ([^}]+) }}/{$1\[$2]}/xg;
    $self->content($new_content);
}

sub categories_sorted {
    my $self = shift;
    return sort {lc($a) cmp lc($b)} @{$self->metadata->Category};
}

sub html_escaped_categories {
    my $self = shift;
    return map { $self->html_escape($_) } $self->categories_sorted;
}

sub metadata {
    my $self = shift;
    return $self->{metadata} = shift if @_;
    $self->{metadata} ||=
      Socialtext::PageMeta->new(hub => $self->hub, id => $self->id);
    return $self->{metadata} if $self->{metadata}->loaded;
    $self->load_metadata;
    return $self->{metadata};
}

sub last_edited_by {
    my $self = shift;
    return unless $self->id && $self->metadata->From;

    my $email_address = $self->metadata->From;
    # We have some very bogus data on our system, so this is a really
    # horrible hack to fix it.
    unless ( Email::Valid->address($email_address) ) {
        my ($name) = $email_address =~ /([\w-]+)/;
        $name = 'unknown' unless defined $name;
        $email_address = $name . '@example.com';
    }

    my $user = eval { Socialtext::User->Resolve( $email_address ) };

    # There are many usernames in pages that were never in the users
    # table.  We need to have all users in the DBMS, so
    # we assume that if they don't exist, they should be created. When
    # we import pages into the DBMS, we'll need to create any
    # non-existent users at the same time, for referential integrity.
    $user ||= eval { Socialtext::User->create(
        username         => $email_address,
        email_address    => $email_address,
    ) };
    $user ||= Socialtext::User->Guest;

    return $user;
}

sub size {
    my $self = shift;
    my $filename = $self->_index_path or return 0;
    return scalar((stat($filename))[7]);
}

sub _index_path {
    my $self = shift;
    my $filename = readlink $self->_get_index_file;
    return unless defined $filename;
    return unless -f $filename;
    return $filename;
}

sub modified_time {
    my $self = shift;
    unless (defined $self->{modified_time}) {
        my $path = $self->file_path;
        $self->{modified_time} = (stat($path))[9] || time;
    }
    return $self->{modified_time};
}

sub is_recently_modified {
    my $self = shift;
    my $limit = shift;
    $limit ||= $IS_RECENTLY_MODIFIED_LIMIT;

    return $self->age_in_seconds < $limit;
}

sub age_in_minutes {
    my $self = shift;
    $self->age_in_seconds / 60;
}

sub age_in_seconds {
    my $self = shift;
    my $time = $REFERENCE_TIME || time;
    return $self->{age_in_seconds} = shift if @_;
    return $self->{age_in_seconds} if defined $self->{age_in_seconds};
    return $self->{age_in_seconds} = ($time - $self->modified_time);
}

sub age_in_english {
    my $self = shift;
    my $age = $self->age_in_seconds;
    my $english =
    $age < 60 ? loc('[_1] seconds', $age) :
    $age < 3600 ? loc('[_1] minutes', int($age / 60)) :
    $age < 86400 ? loc('[_1] hours', int($age / 3600)) :
    $age < 604800 ? loc('[_1] days', int($age / 86400)) :
    $age < 2592000 ? loc('[_1] weeks', int($age / 604800)) :
    loc('[_1] months', int($age / 2592000));

    $english =~ s/^(1 .*)s$/$1/;
    return $english;
}

sub hard_set_date {
    my $self = shift;
    my $date = shift;
    my $user = shift;
    $self->metadata->Date($date->strftime('%Y-%m-%d %H:%M:%S GMT'));
    $self->store( user => $user );
    utime $date->epoch, $date->epoch, $self->file_path;
    $self->{modified_time} = $date->epoch;
}

sub datetime_for_user {
    my $self = shift;
    if (my $date = $self->metadata->Date) {
        return $self->hub->timezone->date_local($date);
    }

    # XXX metadata starts out life as empty string
    return '';
}


sub time_for_user {
    my $self = shift;
    if (my $date = $self->metadata->Date) {
        return $self->hub->timezone->time_local($date);
    }

    # XXX metadata starts out life as empty string
    return '';
}

sub all {
    my $self = shift;
    return (
        page_uri => $self->uri,
        page_title => $self->title,
        page_title_uri_escaped => $self->uri_escape($self->title),
        revision_id => $self->revision_id,
    );
}

sub to_html_or_default {
    my $self = shift;
    $self->to_html($self->content_or_default, $self);
}

sub content_or_default {
    my $self = shift;
    return $self->is_spreadsheet
        ? ($self->content || loc('Creating a New Spreadsheet...') . '   ')
        : ($self->content || loc('Replace this text with your own.') . '   ');
}

sub get_units {
    my $self    = shift;
    my %matches = @_;
    my @units;

    my $chunker = sub {
        my $content_ref = shift;
        _chunk_it_up( $content_ref, sub {
            my $chunk_ref = shift;
            $self->_get_units_for_chunk(\%matches, $chunk_ref, \@units);
        });
    };

    my $content = $self->content;
    if ($self->is_spreadsheet) {
        require Socialtext::Sheet;
        my $sheet = Socialtext::Sheet->new(sheet_source => \$content);
        my $valueformats = $sheet->_sheet->{valueformats};
        for my $cell_name (@{ $sheet->cells }) {
            my $cell = $sheet->cell($cell_name);

            my $valuesubtype = substr($cell->valuetype || ' ', 1);
            if ($valuesubtype eq "w" or $valuesubtype eq "r") {
                # This is a wikitext/richtext cell - proceed
            }
            else {
                my $tvf_num = $cell->textvalueformat
                    || $sheet->{defaulttextvalueformat};
                next unless defined $tvf_num;
                my $format = $valueformats->[$tvf_num];
                next unless defined $format;
                next unless $format =~ m/^text-wiki/;
            }

            # The Socialtext::Formatter::Parser expects this content
            # to end in a newline.  Without it no links will be found for
            # simple pages.
            $content = $cell->datavalue . "\n";

            $chunker->(\$content);
        }
    }
    else {
        $chunker->(\$content);
    }

    return \@units;
}

sub _get_units_for_chunk {
    my $self = shift;
    my $matches = shift;
    my $content_ref = shift;
    my $units = shift;

    my $parser = Socialtext::Formatter::Parser->new(
        table      => $self->hub->formatter->table,
        wafl_table => $self->hub->formatter->wafl_table
    );
    my $parsed_unit = $parser->text_to_parsed( $$content_ref );
    {
        no warnings 'once';
        # When we use get_text to unwind the parse tree and give
        # us the content of a unit that contains units, we need to
        # make sure that we get the right stuff as get_text is
        # called recursively. This insures we do.
        local *Socialtext::Formatter::WaflPhrase::get_text = sub {
            my $self = shift;
            return $self->arguments;
        };
        my $sub = sub {
            my $unit         = shift;
            my $formatter_id = $unit->formatter_id;
            if ( $matches->{$formatter_id} ) {
                push @$units, $matches->{$formatter_id}($unit);
            }
        };
        $self->traverse_page_units($parsed_unit->units, $sub);
    }
}

=head2 $page->traverse_page_units($units, $sub)

Traverse the parse tree of a page to perform the 
actions described in $sub on each unit. $sub is
passed the current unit.

$units is usually the result of
C<Socialtext::Formatter::text_to_parsed($content)->units>

The upshot of that is that this method expects a 
list of units, not a single unit. This makes it
easy for it to be recursive.

=cut
# REVIEW: This should probably be somewhere other than Socialtext::Page
# but where? Socialtext::Formatter? Socialtext::Formatter::Unit?
sub traverse_page_units {
    my $self  = shift;
    my $units = shift;
    my $sub   = shift;

    foreach my $unit (@$units) {
        if (ref $unit) {
            $sub->($unit);
            if ($unit->units) {
                $self->traverse_page_units($unit->units, $sub);
            }
        }
    }
}

sub _chunk_it_up {
    my $content_ref = shift;
    my $callback    = shift;

    # The WikiText::Parser doesn't yet handle really large chunks,
    # so we should chunk this up ourself.
    my $chunk_start = 0;
    my $chunk_size  = 100 * 1024;
    while (1) {
        my $chunk = substr( $$content_ref, $chunk_start, $chunk_size );
        last unless length $chunk;
        $chunk_start += length $chunk;

        $callback->(\$chunk);
    }
}


sub to_absolute_html {
    my $self = shift;
    my $content = shift;

    my %p = @_;
    $p{link_dictionary}
        ||= Socialtext::Formatter::AbsoluteLinkDictionary->new();

    my $url_prefix = $self->hub->current_workspace->uri;

    $url_prefix =~ s{/[^/]+/?$}{};


    $self->hub->viewer->url_prefix($url_prefix);
    $self->hub->viewer->link_dictionary($p{link_dictionary});
    # REVIEW: Too many paths to setting of page_id and too little
    # clearness about what it is for. appears to only be used
    # in WaflPhrase::parse_wafl_reference
    $self->hub->viewer->page_id($self->id);

    if ($content) {
        return $self->to_html($content);
    }
    return $self->to_html($self->content, $self);
}

sub to_html {
    my $self = shift;
    my $content = @_ ? shift : $self->content_or_default;
    my $page = shift;
    $content = '' unless defined $content;

    return $self->hub->pluggable->hook('render.sheet.html', [\$content, $self])
        if $self->is_spreadsheet;

    if ($DISABLE_CACHING) {
        return $self->hub->viewer->process($content, $page);
    }

    # Look for cached HTML
    my $q_file = $self->_question_file;
    if ($q_file and -e $q_file) {
        my $q_str = Socialtext::File::get_contents($q_file);
        my $a_str = $self->_questions_to_answers($q_str);
        my $cache_file = $self->_answer_file($a_str);
        my $cache_file_exists = $cache_file && -e $cache_file;
        my $users_changed = 0;
        if ($cache_file_exists) {
            my $cached_at = (stat($cache_file))[9];
            $users_changed = $self->_users_modified_since($q_str, $cached_at)
        }
        if ($cache_file_exists and !$users_changed) {
            my $t = time_scope('wikitext_HIT');
            $self->{__cache_hit}++;
            warn "HIT: $cache_file" if $CACHING_DEBUG;
            return scalar Socialtext::File::get_contents_utf8($cache_file);
        }

        my $t = time_scope('wikitext_MISS');
        warn "MISS on content" if $CACHING_DEBUG;
        my $html = $self->hub->viewer->process($content, $page);

        # Check if we are the "current" page, and do not cache if we are not.
        # This is to avoid crazy errors where we may be rendering other page's
        # content for TOC wafls and such.
        my $is_current = $self->hub->pages->current->id eq $self->id;
        if (defined $a_str and $is_current) {
            # cache_file may be undef if the answer string was too long.
            # XXX if long answers get hashed we can still save it here
            Socialtext::File::set_contents_utf8_atomic($cache_file, $html)
                if $cache_file;
            warn "MISSED: $cache_file" if $CACHING_DEBUG;
            return $html;
        }
        # Our answer string was invalid, so we'll need to re-generate the Q file
        # We will pass in the rendered html to save work
        return ${ $self->_cache_html(\$html) };
    }

    my $html_ref = $self->_cache_html;
    return $$html_ref;
}

sub _cache_html {
    my $self = shift;
    my $html_ref = shift;
    return if $self->is_spreadsheet;

    my $t = time_scope('cache_wt');

    my $cur_ws = $self->hub->current_workspace;
    my %cacheable_wafls = map { $_ => 1 } qw/
        Socialtext::Formatter::TradeMark 
        Socialtext::Formatter::Preformatted 
        Socialtext::PageAnchorsWafl
        Socialtext::Wikiwyg::FormattingTestRunAll
        Socialtext::Wikiwyg::FormattingTest
        Socialtext::ShortcutLinks::Wafl
    /;
    require Socialtext::CodeSyntaxPlugin;
    for my $brush (keys %Socialtext::CodeSyntaxPlugin::Brushes) {
        $cacheable_wafls{"Socialtext::CodeSyntaxPlugin::Wafl::$brush"} = 1;
    }
    my %not_cacheable_wafls = map { $_ => 1 } qw/
        Socialtext::Formatter::SpreadsheetInclusion
        Socialtext::Formatter::PageInclusion
        Socialtext::RecentChanges::Wafl
        Socialtext::Category::Wafl
        Socialtext::Search::Wafl
    /;
    my @cache_questions;
    my %interwiki;
    my %allows_html;
    my %users;
    my %attachments;
    my $expires_at;

    {
        no warnings 'redefine';
        # Maybe in the future un-weaken the hub so this hack isn't needed. 
        local *Socialtext::Formatter::WaflPhrase::hub = sub {
            my $wafl = shift;
            return $wafl->{hub} || $self->hub;
        };
        $self->get_units(
            wafl_phrase => sub {
                my $wafl = shift;

                my $wafl_expiry = 0;
                my $wafl_class = ref $wafl;

                # Some short-circuts based on the wafl class
                return if $cacheable_wafls{ $wafl_class };
                if ($not_cacheable_wafls{$wafl_class}) {
                    $expires_at = -1;
                    return;
                }

                my $unknown = 0;
                if ($wafl_class =~ m/(?:Image|File|InterWikiLink|HtmlPage|Toc|CSS)$/) {
                    my @args = $wafl->arguments =~ $wafl->wafl_reference_parse;
                    $args[0] ||= $self->hub->current_workspace->name;
                    $args[1] ||= $self->id;
                    my ($ws_name, $page_id, $file_name) = @args;
                    $interwiki{$ws_name}++;
                    if ($file_name) {
                        my $attach_id = $wafl->get_file_id($ws_name, $page_id,
                            $file_name);
                        $attachments{
                            join ' ', $ws_name, $page_id, $file_name, $attach_id
                        }++;
                    }
                }
                elsif ($wafl_class =~ m/(?:TagLink|CategoryLink|WeblogLink|BlogLink)$/) {
                    my ($ws_name) = $wafl->parse_wafl_category;
                    $interwiki{$ws_name}++ if $ws_name;
                }
                elsif ($wafl_class eq 'Socialtext::FetchRSS::Wafl'
                    or $wafl_class eq 'Socialtext::VideoPlugin::Wafl'
                ) {
                    # Feeds and videos are cached for 1 hour, so we can cache this render for 1h
                    # There may be an edge case initially where a feed
                    # ends up getting cached for at most 2 hours if the Question
                    # had not yet been generated.
                    $wafl_expiry = 3600;
                }
                elsif ($wafl_class eq 'Socialtext::GoogleSearchPlugin::Wafl') {
                    # Cache google searches for 5 minutes
                    $wafl_expiry = 300;
                }
                elsif ($wafl_class eq 'Socialtext::Pluggable::WaflPhrase') {
                    if ($wafl->{method} eq 'user') {
                        $users{$wafl->{arguments}}++ if $wafl->{arguments};
                    }
                    else {
                        $unknown = 1;
                    }
                }
                elsif ($wafl_class eq 'Socialtext::Date::Wafl') {
                    # Must cache on date prefs
                    my $prefs = $self->hub->preferences_object;

                    # XXX We really only need to do this once per page.
                    push @cache_questions, {
                        date => join ',',
                            $prefs->date_display_format->value,
                            $prefs->time_display_12_24->value,
                            $prefs->time_display_seconds->value,
                            $prefs->timezone->value
                    };
                }
                elsif ($wafl_class eq 'Socialtext::Category::Wafl') {
                    if ($wafl->{method} =~ m/^(?:tag|category)_list$/) {
                        # We do not cache tag list views
                        $expires_at = -1;
                    }
                    else {
                        $unknown = 1;
                    }
                }
                else {
                    $unknown = 1;
                }

                if ($unknown) {
                    # For unknown wafls, set expiry to be a second ago so 
                    # the page is never cached.
                    warn "Unknown wafl phrase: " . ref($wafl) . ' - ' . $wafl->{method};
                    $expires_at = -1;
                }

                if ($wafl_expiry) {
                    # Keep track of the lowest expiry time.
                    if (!$expires_at or $expires_at > $wafl_expiry) {
                        $expires_at = $wafl_expiry;
                    }
                }
            },
            wafl_block => sub {
                my $wafl = shift;
                my $wafl_class = ref($wafl);
                return if $cacheable_wafls{ $wafl_class };
                if ($wafl->can('wafl_id') and $wafl->wafl_id eq 'html') {
                    $allows_html{$cur_ws->workspace_id}++;
                }
                else {
                    # Do not cache pages with unknown blocks present
                    $expires_at = -1;
                    warn "Unknown wafl block: " . ref($wafl);
                }
            },
        );
    }

    delete $interwiki{ $cur_ws->name };
    for my $ws_name (keys %interwiki) {
        my $ws = Socialtext::Workspace->new(name => $ws_name);
        push @cache_questions, { workspace => $ws } if $ws;
    }
    for my $ws_id (keys %allows_html) {
        my $ws = Socialtext::Workspace->new(workspace_id => $ws_id);
        push @cache_questions, { allows_html_wafl => $ws } if $ws;
    }
    for my $user_id (keys %users) {
        push @cache_questions, { user_id => $user_id };
    }
    for my $attachment (keys %attachments) {
        push @cache_questions, { attachment => $attachment };
    }
    if (defined $expires_at) {
        $expires_at += time();
        push @cache_questions, { expires_at => $expires_at };
    }
    
    eval {
        $html_ref = $self->_cache_using_questions( \@cache_questions, $html_ref );
    }; die "Failed to cache using questions: $@" if $@;

    return $html_ref;
}

sub _cache_using_questions {
    my $self = shift;
    my $questions = shift;
    my $html_ref = shift;

    my @short_q;
    my @answers;

    # Do one pass looking for expiry Q's, as they are cheap to early-out
    for my $q (@$questions) {
        if (my $t = $q->{expires_at}) {
            push @short_q, 'E' . $t;
            # We just made it, so it's not expired yet
            push @answers, 1;
        }
    }

    my $page_attachments;
    for my $q (@$questions) {
        my $ws;
        if ($ws = $q->{workspace}) {
            push @short_q, 'w' . $ws->workspace_id;
            push @answers, $self->hub->authz->user_has_permission_for_workspace(
                user => $self->hub->current_user,
                permission => ST_READ_PERM,
                workspace => $ws
            ) ? 1 : 0;
        }
        elsif (my $user_id = $q->{user_id}) {
            my $user = eval { Socialtext::User->Resolve($user_id) } or next;
            push @short_q, 'u' . $user->user_id;
            push @answers, 1; # All users are linkable.
        }
        elsif ($ws = $q->{allows_html_wafl}) {
            push @short_q, 'h' . $ws->workspace_id;
            push @answers, $ws->allows_html_wafl ? 1 : 0;
        }
        elsif (my $t = $q->{expires_at}) {
            # Skip, it's handled above.
        }
        elsif (my $d = $q->{date}) {
            push @short_q, 'd' . $d;
            push @answers, 1;
        }
        elsif (my $a = $q->{attachment}) {
            push @short_q, 'a' . $a;
            $a =~ m/^(\S+) (\S+) (.+) (\S+)$/;
            push @answers, $self->hub->attachments->attachment_exists(
                $1, $2, $3, $4);
        }
        else {
            die "Unknown question: " . Dumper $q;
        }
    }

    my $q_str = join "\n", @short_q;
    $q_str ||= 'null';

    my $q_file = $self->_question_file or return;
    Socialtext::File::set_contents_utf8_atomic($q_file, \$q_str) if $q_file;

    $html_ref ||= \$self->to_html;

    # Check if we are the "current" page, and do not cache if we are not.
    # This is to avoid crazy errors where we may be rendering other page's
    # content for TOC wafls and such.
    my $is_current = $self->hub->pages->current->id eq $self->id;
    if ($is_current) {
        my $answer_str = join '-', $self->_stock_answers(),
            map { $_ . '_' . shift(@answers) } @short_q;

        my $cache_file = $self->_answer_file($answer_str);
        if ($cache_file) {
            Socialtext::File::set_contents_utf8_atomic($cache_file, $html_ref);
        }
    }
    return $html_ref;
}

sub _users_modified_since {
    my $self = shift;
    my $q_str = shift;
    my $cached_at = shift;

    my @found_users;
    my @user_ids;
    while ($q_str =~ m/(?:^|-)u(\d+)(?:-|$)/gm) {
        push @user_ids, $1;
    }
    return 0 unless @user_ids;

    my $user_placeholders = '?,' x @user_ids; chop $user_placeholders;
    return sql_singlevalue(qq{
        SELECT count(user_id) FROM users
         WHERE user_id IN ($user_placeholders)
           AND last_profile_update >
                'epoch'::timestamptz + ? * INTERVAL '1 second'
        }, @user_ids, $cached_at) || 0;
}

sub _stock_answers {
    my $self = shift;
    my @answers;

    # Which link dictionary is always the first question
    my $ld = ref($self->hub->viewer->link_dictionary);
    push @answers, $ld;

    # Which formatter is always the second question
    push @answers, ref($self->hub->formatter);

    # Which URI scheme is always the third question
    require Socialtext::URI;
    my %uri = Socialtext::URI::_scheme();
    push @answers, $uri{scheme};
    
    return @answers;
};

sub _questions_to_answers {
    my $self = shift;
    my $q_str = shift;

    my $t = time_scope('QtoA');
    my $cur_user = $self->hub->current_user;
    my $authz = $self->hub->authz;

    my @answers = $self->_stock_answers;

    for my $q (split "\n", $q_str) {
        if ($q =~ m/^w(\d+)$/) {
            my $ws = Socialtext::Workspace->new(workspace_id => $1);
            my $ok = $ws && $self->hub->authz->user_has_permission_for_workspace(
                user => $cur_user,
                permission => ST_READ_PERM,
                workspace => $ws,
            ) ? 1 : 0;
            push @answers, "${q}_$ok";
        }
        elsif ($q =~ m/^u(\d+)$/) {
            my $user = Socialtext::User->new(user_id => $1);
            push @answers, "${q}_1"; # All users are linkable
        }
        elsif ($q =~ m/^h(\d+)$/) {
            my $ws = Socialtext::Workspace->new(workspace_id => $1);
            my $ok = $ws && $ws->allows_html_wafl() ? 1 : 0;
            push @answers, "${q}_$ok";
        }
        elsif ($q =~ m/^E(\d+)$/) {
            my ($expires_at, $now) = ($1, time());
            my $ok = $now < $expires_at ? 1 : 0;
            warn "Checking Expiry ($now < $expires_at) = $ok" if $CACHING_DEBUG;
            return undef unless $ok;
            push @answers, "${q}_1";
        }
        elsif ($q =~ m/^d(.+)$/) {
            my $pref_str = $1;
            my $prefs = $self->hub->preferences_object;
            my $my_prefs = join ',',
                $prefs->date_display_format->value,
                $prefs->time_display_12_24->value,
                $prefs->time_display_seconds->value,
                $prefs->timezone->value;
            my $ok = $pref_str eq $my_prefs;
            push @answers, "${q}_$ok";
        }
        elsif ($q =~ m/^a(\S+) (\S+) (.+) (\S+)$/) {
            my $e = $self->hub->attachments->attachment_exists($1, $2, $3, $4);
            if ($e and !$4) {
                warn "Attachment $1/$2/$3 exists, but attachment_id is 0"
                    . " so we will re-generate the question" if $CACHING_DEBUG;
                return undef;
            }
            push @answers, "${q}_$e";
        }
        elsif ($q eq 'null') {
            next;
        }
        else {
            my $ws_name = $self->hub->current_workspace->name;
            st_log->info("Unknown wikitext cache question '$q' for $ws_name/"
                    . $self->id);
            return undef;
        }
    }
    my $str = join '-', @answers;
    warn "Caching Answers: '$str'" if $CACHING_DEBUG;
    return $str;
}

sub _page_cache_basename {
    my $self = shift;
    my $cache_dir = $self->_cache_dir or return;
    return "$cache_dir/" . $self->id . '-' . $self->revision_id;
}

sub delete_cached_html {
    my $self = shift;
    unlink glob($self->_page_cache_basename . '-*');
}

sub _question_file {
    my $self = shift;
    my $base = $self->_page_cache_basename or return;
    return "$base-Q";
}

sub _answer_file {
    my $self = shift;

    # {bz: 4129}: Don't cache temporary pages during new_page creation.
    unless ($self->exists) {
        warn "Not caching new page" if $CACHING_DEBUG;
        return;
    }

    my $answer_str = shift || '';
    my $base = $self->_page_cache_basename;
    unless ($base) {
        warn "No _page_cache_basename, not caching";
        return;
    }

    # Turn SvUTF8 off before hashing the answer string. {bz: 4474}
    Encode::_utf8_off($answer_str);

    my $filename = "$base-".sha1_hex($answer_str);
    (my $basename = $filename) =~ s#.+/##;
    warn "Answer file: $answer_str => $basename" if $CACHING_DEBUG;
    if (length($basename) > 254) {
        warn "Answer file basename is too long! - $basename";
        return undef;
    }
    return $filename;
}

sub _cache_dir {
    my $self = shift;
    return unless $self->hub;
    return $self->hub->viewer->parser->cache_dir(
        $self->hub->current_workspace->workspace_id);
}


sub is_spreadsheet { $_[0]->metadata->Type eq 'spreadsheet' }

sub delete {
    my $self = shift;
    my %p = @_;

    my $timer = Socialtext::Timer->new;

    Carp::confess('no user given to Socialtext::Page->delete')
        unless $p{user};

    my @indexers = Socialtext::Search::AbstractFactory->GetIndexers(
        $self->hub->current_workspace->name);
    foreach my $attachment ( $self->attachments ) {
        my @args = ($self->uri, $attachment->id);
        for my $indexer (@indexers) {
            $indexer->delete_attachment( @args );
        }
    }

    $self->load;
    $self->content('');
    $self->metadata->Category([]);
    $self->store( user => $p{user} );

    Socialtext::Events->Record({
        event_class => 'page',
        action => 'delete',
        page => $self,
    });
    return;
}

sub purge {
    my $self = shift;

    # clean up the index first
    my $indexer
        = Socialtext::Search::AbstractFactory->GetFactory->create_indexer(
        $self->hub->current_workspace->name );

    foreach my $attachment ( $self->attachments ) {
        $indexer->delete_attachment( $self->uri, $attachment->id );
    }

    $indexer->delete_page( $self->uri);

    my $page_path = $self->directory_path or die "Page has no directory path";
    -d $page_path or die "$page_path does not exist";
    my $attachment_path = join '/', $self->hub->attachments->plugin_directory, $self->id;
    File::Path::rmtree($attachment_path)
      if -e $attachment_path;
    File::Path::rmtree($page_path);

    my $hash    = $self->hash_representation;
    my $wksp_id = $self->hub->current_workspace->workspace_id;

    sql_txn {
        sql_execute('DELETE FROM page WHERE workspace_id = ? and page_id = ?',
            $wksp_id, $hash->{page_id}
        );
        sql_execute('DELETE FROM page_tag WHERE workspace_id = ? and page_id = ?',
            $wksp_id, $hash->{page_id}
        );
    };
}

Readonly my $ExcerptLength => 350;
sub preview_text {
    my $self = shift;

    return $self->preview_text_spreadsheet(@_)
        if $self->is_spreadsheet;

    my $content = shift || $self->content;

    # Gigantic pages caused Perl segfaults. Only need the beginning of the
    # content.
    my $max_length = $ExcerptLength * 2;
    if (length($content) > $max_length) {
        $content = substr($content, 0, $max_length);
        $content =~ s/(.*\n).*/$1/s;
    }

    my $excerpt = $self->_to_plain_text( $content );
    $excerpt = substr( $excerpt, 0, $ExcerptLength ) . '...'
        if length $excerpt > $ExcerptLength;
    return Socialtext::String::html_escape($excerpt);
}

sub preview_text_spreadsheet {
    my $self = shift;

    my $content = shift || $self->content;
    $content = $self->_to_spreadsheet_plain_text($content);

    $content = substr( $content, 0, $ExcerptLength ) . '...'
        if length $content > $ExcerptLength;

    return Socialtext::String::html_escape($content);
}

sub _store_preview_text {
    my $self = shift;
    my $preview_text; # Optional; defaults to $self->preview_text -- see below

    return unless my $index_file = $self->_get_index_file;

    my $filename = readlink $index_file;
    if (not -f $filename) {
        warn "$filename is no good for _store_preview_text";
        return;
    }

    my $mtime = $self->modified_time;
    my $data = $self->_get_contents_decoded_as_utf8($filename);
    my $content = substr($data, 0, index($data, "\n\n") + 1);
    my $old_length = length($content);
    return if $content =~ /^Summary:\ +\S/m;
    $content =~ s/^Summary:.*\n//mg;

    if (@_) {
        # If explicitly specified, use the specified text
        $preview_text = shift;
    }
    else {
        # Otherwise, generate preview based on the newly decoded data
        $preview_text = $self->preview_text(substr($data, $old_length + 1));
    }

    $preview_text = '...' if $preview_text =~ /^\s*$/;
    $preview_text =~ s/\s*\z//;
    return if $preview_text =~ /\n/;
    $content .= "Summary: $preview_text\n";
    $content .= substr($data, $old_length);

    Socialtext::File::set_contents_utf8_atomic($filename, \$content);
    $self->set_mtime($mtime, $filename);
}


sub _get_contents_decoded_as_utf8 {
    my $self = shift;
    my $file = shift;

    my $data = Socialtext::File::get_contents($file);
    my $headers = substr($data, 0, index($data, "\n\n") + 1);
    my $old_length = length($headers);

    # If the page has an encoding, decode it as such.
    if ($headers =~ /^Encoding:\ +utf8\n/m) {
        # The common case is UTF-8, so just decode it.
        return Encode::decode_utf8($data);
    }
    elsif ($headers =~ s/^Encoding:\ +(\S+)\n/Encoding: utf8\n/m) {
        # Decode the page according to its declared encoding.
        my $encoding = $1;
        my $body = substr($data, $old_length);
        return Encode::decode($encoding, $headers . $body);
    }
    else {
        # Force conversion from legacy pages; first try UTF-8, then ISO-8859-1.
        local $@;
        my $data_from_utf8 = eval {
            Encode::decode_utf8($data, Encode::FB_CROAK());
        };
        if ($@) {
            # It was not UTF-8 -- fallback to ISO-8859-1.
            return "Encoding: utf8\n" . Encode::decode('iso-8859-1', $data);
        }
        else {
            # It was UTF-8, so simply prepend the correct header.
            return "Encoding: utf8\n" . $data_from_utf8;
        }
    }
}

sub _to_plain_text {
    my $self    = shift;
    my $content = shift || $self->content;

    if ($self->is_spreadsheet) {
        return $self->_to_spreadsheet_plain_text( $content );
    }

    my $plain_text = '';
    Socialtext::Page::Base::_chunk_it_up( \$content, sub {
        my $chunk_ref = shift;
        $plain_text 
            .= $self->_to_socialtext_wikitext_parser_plain_text($$chunk_ref);
    });
    return $plain_text;
}

sub _to_socialtext_formatter_parser_plain_text {
    my $self    = shift;
    my $content = shift;

    my $parser = Socialtext::Formatter::Parser->new(
        table => $self->hub->formatter->table,
        wafl_table => $self->hub->formatter->wafl_table,
    );
    my $units = $parser->text_to_parsed($content);
    return Socialtext::Formatter::Viewer->to_text( $units );
}

sub _to_socialtext_wikitext_parser_plain_text {
    my $self    = shift;
    my $content = shift;

    my $parser = Socialtext::WikiText::Parser->new(
       receiver => Socialtext::WikiText::Emitter::SearchSnippets->new,
    );

    my $return = "";
    eval { $return = $parser->parse($content) };
    warn $@ if $@;
    return $return;
}

sub _to_spreadsheet_plain_text {
    my $self    = shift;
    my $content = shift;

    require Socialtext::Sheet;
    require Socialtext::Sheet::Renderer;

    my $text = Socialtext::Sheet::Renderer->new(
        sheet => Socialtext::Sheet->new(sheet_source => \$content),
        hub   => $self->hub,
    )->sheet_to_text();

    return $text;
}

# REVIEW: We should consider throwing exceptions here rather than return codes.
sub duplicate {
    my $self = shift;
    my $dest_ws = shift;
    my $target_page_title = shift;
    my $keep_categories = shift;
    my $keep_attachments = shift;
    my $clobber = shift || '';
    my $is_rename = shift || 0;

    my $dest_main = Socialtext->new;
    $dest_main->load_hub(
        current_workspace => $dest_ws,
        current_user      => $self->hub->current_user,
    );
    my $dest_hub = $dest_main->hub;
    $dest_hub->registry->load;

    my $target_page = $dest_hub->pages->new_from_name($target_page_title);

    # XXX need exception handling of better kind
    # Don't clobber an existing page if we aren't clobbering
    if ($target_page->metadata->Revision
            and $target_page->active
            and ($clobber ne $target_page_title)) {
        return 0;
    }

    my $target_page_id = Socialtext::String::title_to_id($target_page_title);
    $target_page->content($self->content);
    $target_page->metadata->Subject($target_page_title);
    $target_page->metadata->Category($self->metadata->Category)
      if $keep_categories;
    $target_page->metadata->update( user => $dest_hub->current_user );

    $target_page->metadata->Type($self->metadata->Type);

    if ($keep_attachments) {
        my @attachments = $self->attachments();
        for my $source_attachment (@attachments) {
            my $target_attachment = $dest_hub->attachments->new_attachment(
                    id => $source_attachment->id,
                    page_id => $target_page_id,
                    filename => $source_attachment->filename,
                );

            my $target_directory = $dest_hub->attachments->plugin_directory;
            $target_attachment->copy($source_attachment, $target_attachment, $target_directory);
            $target_attachment->store( user => $dest_hub->current_user,
                                       dir  => $target_directory );
        }
    }

    $target_page->store( user => $dest_hub->current_user );

    Socialtext::Events->Record({
        event_class => 'page',
        action => ($is_rename ? 'rename' : 'duplicate'),
        page => $self,
        target_workspace => $dest_hub->current_workspace,
        target_page => $target_page,
    });

    Socialtext::Events->Record({
        event_class => 'page',
        action => 'edit_save',
        page => $target_page,
    });

    return 1; # success
}

# REVIEW: We should consider throwing exceptions here rather than return codes.
sub rename {
    my $self = shift;
    my $new_page_title = shift;
    my $keep_categories = shift;
    my $keep_attachments = shift;
    my $clobber = shift || '';

    # If the new title of the page has the same page-id as the old then just
    # change the title, and don't mess with the other bits.
    my $new_id = Socialtext::String::title_to_id($new_page_title);
    if ( $self->id eq $new_id ) {
        $self->title($new_page_title);
        $self->metadata->Subject($new_page_title);
        $self->metadata->update( user => $self->hub->current_user );
        $self->store( user => $self->hub->current_user );
        return 1;
    }

    my $return = $self->duplicate(
        $self->hub->current_workspace,
        $new_page_title,
        $keep_categories,
        $keep_attachments,
        $clobber,
        'rename'
    );

    if ($return) {
        my $localized_str = loc("Page renamed to [_1]", $new_page_title);
        $localized_str =~ s/^Page\ renamed\ to\ /Page\ renamed\ to\ \[/;
        $localized_str =~ s/$/\]/;
        $self->content($localized_str);
        $self->metadata->Type("wiki");
        $self->store( user => $self->hub->current_user );
    }

    return $return;
}

# REVIEW: Candidate for Socialtext::Validate
sub _validate_has_addresses {
    my $self = shift;
    return (
        (not defined($_[0])) # May be undef
            or
        (not ref $_[0])      # or an address
            or
        (@{$_[0]} >= 1)      # or list of one or more addresses
    );
}

sub send_as_email {
    my $self = shift;
    my %p = validate(@_, {
        from => SCALAR_TYPE,
        to => {
            type => SCALAR | ARRAYREF | UNDEF, default => undef,
            callbacks => { 'has addresses or send_copy' => sub {
                my ($val, $params) = @_;
                $params->{send_copy} or $self->_validate_has_addresses(@_);
            } }
        },
        cc => {
            type => SCALAR | ARRAYREF | UNDEF, default => undef,
            callbacks => { 'has addresses' => sub { $self->_validate_has_addresses(@_) } }
        },
        subject => { type => SCALAR, default => $self->title },
        body_intro => { type => SCALAR, default => '' },
        include_attachments => { type => BOOLEAN, default => 0 },
        send_copy => { type => BOOLEAN, default => 0 },
    });
    
    # If send_copy is specified and no to address, make the
    # to address be equal to the from address
    if (!$p{to} && $p{send_copy}) {
        $p{to} = $p{from};
    }

    die "Must provide at least one address via the to or cc parameters"
      unless $p{to} || $p{cc};

    if ( $p{cc} and not $p{to} ) {
        $p{to} = $p{cc};
        delete $p{cc},
    }

    if ($p{send_copy}) {
        if ((!ref($p{to})) && ($p{from} ne $p{to})) {
            $p{to}=[$p{to}, $p{from}];
        } elsif ((ref($p{to}) eq "ARRAY") && 
            (! grep {$_ eq $p{from}} @{$p{to}})) {
            push(@{$p{to}}, $p{from});
        }
    }

    my $body_content;

    my $make_body_content = sub {
        if ($self->is_spreadsheet) {
            my $content = $self->to_absolute_html();
            return $content unless $p{body_intro} =~ /\S/;

            my $intro = $self->hub->viewer->process($p{body_intro}, $self);
            return "$intro<hr/>$content";
        }

        return $self->to_absolute_html( $p{body_intro} . $self->content );
    };

    if ($p{include_attachments}) {
        my $prev_viewer = $self->hub->viewer;
        my $formatter = Socialtext::Pages::Formatter->new(hub => $self->hub);
        $self->hub->viewer->parser(
            Socialtext::Formatter::Parser->new(
                table => $formatter->table,
                wafl_table => $formatter->wafl_table
            )
        );
        $body_content = $make_body_content->();
        $self->hub->viewer($prev_viewer);
    }
    else {
        # If we don't have attachments, don't link to nonexistent "cid:" hrefs. {bz: 1418}
        $body_content = $make_body_content->();
    }

    my $html_body = $self->hub->template->render(
        'page_as_email.html',
        title        => $p{subject},
        body_content => $body_content,
    );

    my $text_body = Text::Autoformat::autoformat(
        $p{body_intro} . ($self->is_spreadsheet ? "\n" : $self->content), {
            all    => 1,
            # This won't actually work properly until the next version
            # of Text::Autoformat, as 1.13 has a bug.
            ignore =>
                 qr/# this regex is copied from Text::Autoformat ($ignore_indented)
                   (?:^[^\S\n].*(\n[^\S\n].*)*$)
                   |
                   # this matches table rows
                   (?:^\s*\|(?:(?:[^\|]*\|)+\n)+$)
                  /x,
        },
    );

    my %email = (
        to        => $p{to},
        subject   => $p{subject},
        from      => $p{from},
        text_body => $text_body,
        html_body => $html_body,
    );
    $email{cc} = $p{cc} if defined $p{cc};
    $email{attachments} =
        [ map { $_->full_path() } $self->attachments ]
            if $p{include_attachments};

    my $locale = system_locale();
    my $email_sender = Socialtext::EmailSender::Factory->create($locale);
    $email_sender->send(%email);
}

sub is_in_category {
    my $self = shift;
    my $category = shift;

    grep {$_ eq $category} @{$self->metadata->Category};
}

sub locked {
    my $self = shift;

    return $self->metadata->Locked;
}

sub deleted {
    my $self = shift;
    $self->metadata->Control eq 'Deleted';
}

sub load_revision {
    my $self = shift;
    my $revision_id = shift;

    $self->revision_id($revision_id);
    return $self->load;
}

sub load {
    my $self        = shift;
    my $page_string = shift;

    my $metadata = $self->{metadata}
        or die "No metadata object in content object";

    my $headers;
    if ($page_string) {
        $headers = $self->_read_page_string($page_string);
    }
    else {
        $headers = $self->_read_page_file();
    }
    $metadata->from_hash($self->parse_headers($headers));
    return $self;
}

sub load_content {
    my $self = shift;
    my $content = $self->_read_page_file(content => 1);
    $self->content($content);
    return $self;
}

sub load_metadata {
    my $self = shift;
    my $metadata = $self->{metadata}
      or die "No metadata object in content object";
    my $headers = $self->_read_page_file();
    $metadata->from_hash($self->parse_headers($headers));
    $metadata->{Type} ||= 'wiki';
    return $self;
}

sub parse_headers {
    my $self = shift;
    my $headers = shift;
    my $metadata = {};
    for (split /\n/, $headers) {
        next unless /^(\w\S*):\s*(.*)$/;
        my ($attribute, $value) = ($1, $2);
        if (defined $metadata->{$attribute}) {
            $metadata->{$attribute} = [$metadata->{$attribute}]
              unless ref $metadata->{$attribute};
            push @{$metadata->{$attribute}}, $value;
        }
        else {
            $metadata->{$attribute} = $value;
        }
    }

    # Putting whacky whitespace in a page title can kill javascript on the
    # front-end. This fixes {bz: 3475}.
    if ($metadata->{Subject}) {
        $metadata->{Subject} =~ s/\s/ /g;
    }

    return $metadata;
}

# This method is used only by testing tool.
sub _read_page_string {
    my $self = shift;
    my $string = shift;

    die "Not a string ($string)" if ref($string);
    my ($headers, $content) = split "\n\n", $string, 2;
    $self->content($content);
    return $headers;
}

sub _read_page_file {
    my $self   = shift;
    my %p      = @_;
    my $return_content = $p{content};

    my $revision_id = $self->assert_revision_id;
    return $self->_read_empty unless $revision_id;
    my $filename = $self->current_revision_file;
    return read_and_decode_file($filename, $return_content);
}

sub read_and_decode_file {
    my $filename       = shift;
    my $return_content = shift;
    die "No such file $filename" unless -f $filename;
    die "File path contains '..', which is not allowed."
        if $filename =~ /\.\./;

    # Note: avoid using '<:raw' here, it sucks for performance
    open(my $fh, '<', $filename)
        or die "Can't open $filename: $!";
    binmode($fh); # will Encode bytes to characters later

    my $buffer;
    {
        # slurp in the header only:
        local $/ = "\n\n";
        $buffer = <$fh>;
    }

    if ($return_content) { 
        # slurp in the rest of the file:
        local $/ = undef;
        $buffer = <$fh> || '';
    }

    $buffer = Socialtext::Encode::noisy_decode(
            input => $buffer,
            blame => $filename
    );

    $buffer =~ s/\015\012/\n/g;
    $buffer =~ s/\015/\n/g;
    return $buffer;
}

sub _read_empty {
    my $self = shift;
    my $text = '';
    $self->utf8_decode($text);
}

{
    Readonly my $spec => {
        revision_id => POSITIVE_INT_TYPE,
        user        => USER_TYPE,
    };
    sub restore_revision {
        my $self = shift;
        my %p = validate( @_, $spec );
        my $id = shift;

        $self->revision_id( $p{revision_id} );
        $self->load;
        $self->store( user => $p{user} );
    }
}

sub edit_in_progress {
    my $self = shift;

    my $reporter = Socialtext::Events::Reporter->new(
        viewer => $self->hub->current_user,
    );

    my $yesterday = DateTime->now() - DateTime::Duration->new( days => 1 );
    my $events = $reporter->get_page_contention_events({
        page_workspace_id => $self->hub->current_workspace->workspace_id,
        page_id => $self->id,
        after  => $yesterday,
    }) || [];

    my $cur_rev = $self->revision_id;
    my @relevant_events;
    for my $evt (@$events) {
        last if $evt->{context}{revision_id} < $cur_rev;
        unshift @relevant_events, $evt;
    }

    my %open_edits;
    for my $evt (@relevant_events) {
        my $actor_id = $evt->{actor}{id};
        if ($evt->{action} eq 'edit_start') {
            if (my $e = $open_edits{ $actor_id }) {
                push @{ $open_edits{ $actor_id }}, $evt;
            }
            else {
                $open_edits{ $actor_id } = [ $evt ];
            }
        }

        if ($evt->{action} eq 'edit_cancel') {
            my $evts = $open_edits{ $actor_id };
            if ($evts) {
                pop @$evts;
                delete $open_edits{$actor_id} if @$evts == 0;
            }
            # otherwise ignore the cancel
        }
    }

    if (%open_edits) {
        my @edits = sort { $a->{at} cmp $b->{at} }
                    map { @{$open_edits{$_}} }
                    keys %open_edits;
        for my $evt (@edits) {
            my $user = Socialtext::User->new(user_id => $evt->{actor}{id});
            return {
                user_id => $user->user_id,
                username => $user->best_full_name,
                email_address => $user->email_address,
                user_business_card => $self->hub->pluggable->hook(
                    'template.user_business_card.content', [$user->user_id]),
                user_link => $self->hub->pluggable->hook(
                    'template.open_user_link.content', [$user->user_id]
                ),
                minutes_ago   => int((time - str2time($evt->{at})) / 60 ),
            };
        }
    }

    return undef;
}

sub headers {
    my $self = shift;
    my $metadata = $self->metadata;
    my $hash = $metadata->to_hash;
    my @keys = $metadata->key_order;
    my $headers = '';
    for my $key (@keys) {
        my $attribute = $key;
        $key =~ s/^([A-Z][a-z]+)([A-Z].*)$/$1-$2/;
        my $value = $metadata->$attribute;
        next unless defined $value;
        unless (ref $value) {
            $value =~ tr/\r\n/  /s;
            $value = [$value];
        }
        $headers .= "$key: $_\n" for grep {defined $_ and length $_} @$value;
    }
    return $headers;
}

sub write_file {
    my $self = shift;
    my $id = $self->id
      or die "No id for content object";
    my $revision_file = $self->revision_file( $self->new_revision_id );
    my $page_path = join '/', Socialtext::Paths::page_data_directory( $self->hub->current_workspace->name ), $id;
    Socialtext::File::ensure_directory($page_path, 0, 0755);
    my $content = join "\n", $self->headers, $self->content;
    Socialtext::File::set_contents_utf8_atomic($revision_file, \$content);

    my $index_path = join '/', $page_path, 'index.txt';
    Socialtext::File::safe_symlink($revision_file => $index_path);
}

sub current_revision_file {
    my $self = shift;
    $self->revision_file($self->assert_revision_id);
}

sub revision_file {
    my $self = shift;
    my $revision_id = shift;
    my $filename = join '/', 
        ( $self->database_directory, $self->id, $revision_id . '.txt' );
    return $filename;
}

sub new_revision_id {
    my $self = shift;
    my ($sec,$min,$hour,$mday,$mon,$year) = gmtime(time);
    my $id = sprintf(
        "%4d%02d%02d%02d%02d%02d",
        $year + 1900, $mon + 1, $mday, $hour, $min, $sec
    );
    # REVIEW: This is the minimum change to avoid revision id collisions.
    # It's not the best solution, but there are so many options and enough
    # indecision that the wrong way sticks around in pursuit of the 
    # right way. So here's something adequate that does not cascade 
    # changes in the rest of the code.
    unless (-f $self->revision_file($id)) {
        $self->revision_id($id);
        return $id;
    }
    sleep 1;
    return $self->new_revision_id();

}

sub formatted_date {
    # formats the current date/time in iso8601 format
    my $now = DateTime->now();
    my $fmt = DateTime::Format::Strptime->new( pattern => '%F %T %Z' );
    my $res = $fmt->format_datetime( $now );
    $res =~ s/UTC$/GMT/;    # refer to it as "GMT", not "UTC"
    return $res;
}

sub active {
    my $self = shift;
    return $self->exists && not $self->deleted;
}

sub is_bad_page_title {
    my ( $class, $title ) = @_;
    $title = defined($title) ? $title : "";

    # No empty page titles.
    return 1 if $title =~ /^\s*$/;

    # Can't have a page named "Untitled Page"
    my $untitled_page = Socialtext::String::title_to_id( loc("Untitled Page") );
    return 1 if Socialtext::String::title_to_id($title) eq $untitled_page;
    my $untitled_spreadsheet = Socialtext::String::title_to_id( loc("Untitled Spreadsheet") );
    return 1 if Socialtext::String::title_to_id($title) eq $untitled_spreadsheet;

    return 0;
}

sub summary { $_[0]->metadata->Summary }
sub edit_summary { $_[0]->metadata->RevisionSummary }

# This is called by Socialtext::Query::Plugin::push_result
sub to_result {
    my $self = shift;
    my $t = time_scope 'page_to_result';
    my $metadata = $self->metadata;

    my $result = {};
    $result->{$_} = $metadata->$_
      for qw(From Date Subject Revision Summary Type);
    $result->{DateLocal} = $self->datetime_for_user;
    $result->{revision_count} = $self->revision_count;
    $result->{page_uri} = $self->uri;
    $result->{page_id} = $self->id;
    $result->{is_spreadsheet} = $self->is_spreadsheet;
    $result->{create_time} = $self->original_revision->metadata->Date;
    $result->{creator} = $self->creator->username;
    $result->{create_time_local} = $self->original_revision->datetime_for_user;
    my $user = $self->last_edited_by;
    $result->{username} = $user ? $user->username : '';
    if (not $result->{Summary}) {
        my $text = $self->preview_text;
        $self->_store_preview_text($text);
        $result->{Summary} = $text;
    }
    $result->{edit_summary} = $self->edit_summary;
    return $result;
}

sub all_revision_ids {
    my $self = shift;
    return unless $self->exists;

    my $dirname = $self->id;
    my $datadir = $self->directory_path;

    my @files = Socialtext::File::all_directory_files( $datadir );
    my @ids = grep defined, map { /(\d+)\.txt$/ ? $1 : () } @files;

    # No point in sorting if the caller only wants a count.
    return wantarray ? sort( @ids ) : scalar( @ids );
}

sub original_revision {
    my $self = shift;
    my $page_id  = $self->id;
    my $orig_id  = ($self->all_revision_ids)[0];
    return $self if !$page_id || !$orig_id || $page_id eq $orig_id;

    return $self->_load_revision($orig_id);
}

sub _load_revision {
    my $self = shift;
    my $orig_id = shift;
    my $orig_page = Socialtext::Page->new(hub => $self->hub, id => $self->id);
    $orig_page->revision_id( $orig_id );
    $orig_page->load;
    return $orig_page;
}

sub prev_revision {
    my $self = shift;
    for my $rev_id (reverse $self->all_revision_ids) {
        next if $rev_id == $self->revision_id;
        return $self->_load_revision($rev_id);
    }
    return $self;
}

sub attachments {
    my $self = shift;
    return @{ $self->hub->attachments->all( page_id => $self->id ) };
}

sub _log_page_action {
    my $self = shift;

    my $action = $self->hub->action || '';
    my $clobber = eval { $self->hub->rest->query->param('clobber') };

    return if $clobber
        || $action eq 'submit_comment'
        || $action eq 'attachments_upload';

    my $log_action;
    if ($action eq 'delete_page') {
        $log_action = 'DELETE';
    }
    elsif ($action eq 'rename_page') {
        $log_action = ($self->revision_count == 1) ? 'CREATE' : 'RENAME';
    }
    elsif ($action eq 'edit_content') {
        if ($self->restored) {
            $log_action = 'RESTORE';
        }
        elsif ($self->revision_count == 1) {
            $log_action = 'CREATE';
        }
        else {
            $log_action = 'EDIT';
        }
    }
    elsif ($action eq 'revision_restore') {
        $log_action = 'RESTORE';
    }
    elsif ($action eq 'undelete_page') {
        $log_action = 'RESTORE';
    }
    else {
        $log_action = 'CREATE';
    }

    my $ws         = $self->hub->current_workspace;
    my $user       = $self->hub->current_user;

    st_log()->info("$log_action,PAGE,"
                   . 'workspace:' . $ws->name . '(' . $ws->workspace_id . '),'
                   . 'page:' . $self->id . ','
                   . 'user:' . $user->username . '(' . $user->user_id . '),'
                   . '[NA]'
    );
}

1;
