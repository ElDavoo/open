package Socialtext::Lite;
# @COPYRIGHT@
use Moose;
use Readonly;
use Date::Parse qw/str2time/;
use Socialtext::Authen;
use Socialtext::String;
use Socialtext::Permission 'ST_EDIT_PERM';
use Socialtext::Helpers;
use Socialtext::l10n qw(loc);
use Socialtext::Timer;
use Socialtext::Session;
use Socialtext::Formatter::LiteLinkDictionary;

use namespace::clean -except => 'meta';

has 'link_dictionary' => (
    is => 'rw', isa => 'Socialtext::Formatter::LiteLinkDictionary',
    lazy_build => 1,
);

sub _build_link_dictionary { Socialtext::Formatter::LiteLinkDictionary->new }

=head1 NAME

Socialtext::Lite - A set of lightweight entry points to the NLW application

=head1 SYNOPSIS

    my $page_display = Socialtext::Lite->new( hub => $nlw->hub )->display($page);

=head1 DESCRIPTION

NLW can present a variety of views into the data in a workspace, but the entry
points to this activity are often obscured behind many layers of code.
Socialtext::Lite provides a way to perform some of these actions in a
straightforward manner. It assumes that a L<Socialtext::Hub> is already
available and fully initialized.

Socialtext::Lite is currently built as a class from which you create an object
on which to call methods. There's, as yet, not much reason for this but
it makes for a familiar calling convention.

See L<Socialtext::Handler::Page::Lite> for a mod perl Handler that implements
a simple interface to NLW using Socialtext::Lite.

Socialtext::Lite is not fully robust in the face of unexpected conditions.

Socialtext::Lite is trying to be a simple way to create or demonsrate alternate
interfaces to the workspaces, users and pages manages by NLW. In the
process it may suggest ways in which the rest of the system can be 
made more simple, or classes could be extracted into their component
parts.

Socialtext::Lite is limited in functionality by design. Before adding something
ask yourself if it is really necessary.

=head1 URIs in HTML output

Socialtext::Lite returns URIs that begin with /lite/. No index.cgi is used, as
with the traditional interface to NLW. L<Socialtext::Formatter> is tightly 
coupled with it's presentation level, traditional NLW, by default
generating URIs specific to that view. Because of this Socialtext::Lite
overrides some methods in the formatter. These overrides are done in
the _frame_page method.

=cut

# The templates we display with
Readonly my $LOGIN_TEMPLATE          => 'lite/login/login.html';
Readonly my $DISPLAY_TEMPLATE        => 'lite/page/display.html';
Readonly my $EDIT_TEMPLATE           => 'lite/page/edit.html';
Readonly my $CONTENTION_TEMPLATE     => 'lite/page/contention.html';
Readonly my $CHANGES_TEMPLATE        => 'lite/changes/changes.html';
Readonly my $SEARCH_TEMPLATE         => 'lite/search/search.html';
Readonly my $TAG_TEMPLATE            => 'lite/tag/tag.html';
Readonly my $WORKSPACE_LIST_TEMPLATE => 'lite/workspace_list/workspace_list.html';
Readonly my $PAGE_LOCKED_TEMPLATE     => 'lite/page/page_locked.html';
Readonly my $FORGOT_PASSWORD_TEMPLATE => 'lite/forgot_password/forgot_password.html';

=head1 METHODS

=head2 new(hub => $hub)

Creates a new Socialtext::Lite object. If no hub is passed, the Socialtext::Lite
object will be unable to perform.

=cut
sub new {
    my $class = shift;
    my %p     = @_;

    $class = ref($class) || $class;

    my $self = bless {}, $class;

    $self->{hub} = $p{hub};

    return $self;
}

=head2 hub

Returns the hub that will be used to find classes and data. Currently
only an accessor.

=cut
sub hub {
    my $self = shift;
    return $self->{hub};
}

=head2 login()

Shows a mobile version of the login page.

=cut
sub login {
    my $self        = shift;
    my $redirect_to = shift || '/lite/workspace_list';
    my $session     = Socialtext::Session->new();
    return $self->_process_template(
        $LOGIN_TEMPLATE,
        title             => loc('Socialtext Login'),
        redirect_to       => $redirect_to,
        errors            => [ $session->errors ],
        messages          => [ $session->messages ],
        username_label    => Socialtext::Authen->username_label,
        public_workspaces =>
            [ $self->hub->workspace_list->public_workspaces ],
    );
}

=head2 forgot_password()

Shows a mobile version of the forgot_password page.

=cut

sub forgot_password {
    my $self = shift;
    my $session = Socialtext::Session->new();
    return $self->_process_template(
        $FORGOT_PASSWORD_TEMPLATE,
        errors            => [ $session->errors ],
        messages          => [ $session->messages ],
    );
}

=head2 display($page)

Given $page, a L<Socialtext::Page>, returns a string of HTML suitable for
output to a web browser.

=cut
sub display {
    my $self = shift;
    my $page = shift || $self->hub->pages->current;

    my $section = 'page';
    if ($self->hub->current_workspace->title eq $page->title) {
        $section = 'workspace';
    }

    return $self->_frame_page($page, section => $section);
}

=head2 edit_action($page)

Presents HTML including a form for editing $page, a L<Socialtext::Page>.

=cut
sub edit_action {
    my $self = shift;
    my $page = shift;
    return $self->_process_template(
        $EDIT_TEMPLATE,
        page => $page,
    );
}

=head2 edit_save($page)

Expects CGI data provided from the form in C<edit_action>. Updates
$page with content and other data provided by the CGI data.

If no revision_id, revision or subject are provided in the CGI
data, use the information in the provided page object.

=cut 
sub edit_save {
    my $self = shift;
    my %p    = @_;

    my $page = $p{page};
    delete $p{page};

    eval { $page->update_from_remote(%p); };
    if ( $@ =~ /^Contention:/ ) {
        return $self->_handle_contention( $page, $p{subject}, $p{content} );
    }
    elsif ($@ =~ /Page is locked/) {
        return $self->_handle_lock( $page, $p{subject}, $p{content} );
    }
    elsif ($@) {
        # rethrow
        die $@;
    }

    return '';    # insure that we are returning no content
}

=head2 recent_changes

Returns HTML representing the list of the fifty (or less) most 
recently changed pages in the current workspace.

=cut 

sub recent_changes {
    my $self     = shift;
    my $tag = shift || '';
    my $changes = $self->hub->recent_changes->get_recent_changes_in_category(
        count    => 50,
        category => $tag,
    );

    my $title = 'Recent Changes';
    $title .= " in $tag" if $tag;

    return $self->_process_template(
        $CHANGES_TEMPLATE,
        section   => 'recent_changes',
        title     => $title,
        tag       => $tag,
        load_row_times => sub {
            return Socialtext::Query::Plugin::load_row_times(@_);
        },
        %$changes,
    );
}

=head2 workspace_list()

Returns a list of the workspaces that the user has access to, including any
public workspaces.

=cut

sub workspace_list {
    my $self  = shift;
    return $self->_process_template(
        $WORKSPACE_LIST_TEMPLATE,
        title             => loc('Workspace List'),
        section           => 'workspaces',
        my_workspaces     => [ $self->hub->workspace_list->my_workspaces ],
        public_workspaces => [ $self->hub->workspace_list->public_workspaces ],
    );
}

=head2 search([$search_term])

Returns a form for searching the current workspace. If $search_term 
is defined, the results of that search are provided as a list of links
to pages.

=cut 
sub search {
    my $self = shift;
    my $search_term = $self->_utf8_decode(shift);
    my $search_results;
    my $title = 'Search';
    my $error = '';

    if ( $search_term ) {
        eval {
            $search_results = $self->hub->search->get_result_set(search_term => $search_term);
        };
        if ($@) {
            $error = $@;
            $title = 'Search Error';
        }
        else {
            $title = $search_results->{display_title};
        }
    }

    if ($search_results->{too_many}) {
        $error = loc('The search term you have entered is too general; [_1] pages and/or attachments matched your query. Please add additional search terms that you expect your documents contain.', $search_results->{hits});
    }

    return $self->_process_template(
        $SEARCH_TEMPLATE,
        section       => 'search',
        search_term   => $search_term,
        title         => $title,
        search_error  => $error,
        load_row_times => sub {
            return Socialtext::Query::Plugin::load_row_times(@_);
        },
        %$search_results,
    );
}

=head2 tag([$tag])

If $tag is not defined, provide a list of links to all categories
in the current workspace. If $tag is defined, provide a list of
links to all the pages in the tag.

=cut 
sub tag {
    my $self = shift;
    my $tag = $self->_utf8_decode(shift);

    if ($tag) {
        return $self->_pages_for_tag($tag);
    }
    else {
        return $self->_all_tags();
    }
}

sub _pages_for_tag {
    my $self = shift;
    my $tag = shift;

    my $rows = $self->hub->category->get_page_info_for_category($tag);
    return $self->_process_template(
        $TAG_TEMPLATE,
        title     => loc("Tag [_1]", $tag),
        section   => 'tag',
        rows      => $rows,
        tag       => $tag,
        load_row_times => sub {
            return Socialtext::Query::Plugin::load_row_times(@_);
        },
    );
}

sub _all_tags {
    my $self = shift;

    return $self->_process_template(
        $TAG_TEMPLATE,
        title    => loc('Tags'),
        section  => 'tags',
        tags     => [ $self->hub->category->all ],
    );
}


# XXX utf8_decode should be on Socialtext::String not Socialtext::Base
sub _utf8_decode {
    my $self = shift;
    my $text = shift;
    return $self->hub->utf8_decode($text);
}

sub _handle_contention {
    my $self    = shift;
    my $page    = shift;
    my $subject = shift;
    my $content = shift;

    return $self->_process_template(
        $CONTENTION_TEMPLATE,
        title     => "$subject Editing Error",
        content   => $content,
        page      => $page,
    );
}

sub _handle_lock {
    my $self    = shift;
    my $page    = shift;
    my $subject = shift;
    my $content = shift;

    return $self->_process_template(
        $PAGE_LOCKED_TEMPLATE,
        title   => "$subject Editing Error",
        content => $content,
        page    => $page,
    );
}

sub _frame_page {
    my ($self, $page, %args) = @_;

    my $attachments = $self->_get_attachments($page);

    $self->hub->viewer->link_dictionary($self->link_dictionary);
    
    Socialtext::Timer->Continue('lite_page_html');
    my $html = $page->to_html_or_default;
    Socialtext::Timer->Pause('lite_page_html');
    return $self->_process_template(
        $DISPLAY_TEMPLATE,
        page_html        => $html,
        title            => $page->title,
        attachments      => $attachments,
        # XXX next two for attachments, because we are using legacy urls
        # for now
        page             => $page,
        page_locked_for_user  => 
            $page->locked && 
            $self->hub->current_workspace->allows_page_locking &&
            !$self->hub->checker->check_permission('lock'),
        %args,
    );
}

sub _process_template {
    my $self     = shift;
    my $template = shift;
    my %vars     = @_;

    my %ws_vars;
    if ($self->hub->current_workspace->real) {
        %ws_vars = (
            ws => $self->hub->current_workspace,
        );
    }

    my $warning;
    my $ua = $ENV{HTTP_USER_AGENT};
    if (my ($version) = $ua =~ m{^BlackBerry[^/]+/(\S+) }) {
        if ($version < 4.6) {
            $warning = loc("Warning: Socialtext Mobile for BlackBerry requires v4.6 or higher");
        }
    }

    my $user = $self->hub->current_user;
    return $self->hub->template->process(
        $template,
        warning     => $warning,
        miki        => 1,
        user        => $self->hub->current_user,
        brand_stamp => $self->hub->main->version_tag,
        static_path => Socialtext::Helpers::static_path,
        skin_uri    => sub { $self->hub->skin->skin_uri($_[0]) },
        pluggable   => $self->hub->pluggable,
        user        => $user,
        minutes_ago => sub { int((time - str2time(shift)) / 60) },
        %ws_vars,
        %vars,
    );
}

sub _get_attachments {
    my $self = shift;
    my $page = shift;

    my @attachments = sort { lc( $a->filename ) cmp lc( $b->filename ) }
        @{ $self->hub->attachments->all( page_id => $page->id ) };

    return \@attachments;
}

1;

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Socialtext, Inc., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

