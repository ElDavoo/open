# @COPYRIGHT@
package Socialtext::Pages;
use strict;
use warnings;

use base 'Socialtext::Base';

use Class::Field qw( const field );
use Email::Valid;
use Socialtext::Log 'st_log';
use Socialtext::Page;
use Socialtext::Paths;
use Socialtext::WeblogUpdates;
use Readonly;
use Socialtext::Timer qw/time_scope/;
use Socialtext::User;
use Socialtext::Validate qw( validate DIR_TYPE );
use Socialtext::Workspace;
use Socialtext::l10n qw( loc );
use Socialtext::String ();
use Socialtext::SQL qw/sql_execute sql_format_timestamptz/;
use Scalar::Util qw/blessed/;
use Guard qw/scope_guard/;

sub class_id { 'pages' }
const class_title => 'NLW Pages';

field current => 
      -init => '$self->new_page($self->current_id)';

=head2 $page->all()

Returns a list of all page objects that exist in the current workspace.
This includes deleted pages.

=cut
sub all {
    my $self = shift;
    my $t = time_scope 'all_pages';
    return map {$self->new_page($_)} $self->all_ids;
}

=head2 $pages->all_active()

Returns a list of all active page objects that exist in the current
workspace and are active (not deleted).

=cut
sub all_active {
    my $self = shift;
    my $t = time_scope 'all_active';
    return grep {$_->active} $self->all();
}

sub all_ids {
    my $self = shift;
    my %p = @_;
    my $t = time_scope 'all_ids';
    my $hide_deleted = $p{not_deleted} ? "AND NOT deleted" : '';
    my $sth = sql_execute(<<EOT,
SELECT page_id 
    FROM page
    WHERE workspace_id = ?
        $hide_deleted
    ORDER BY last_edit_time DESC
EOT
        $self->hub->current_workspace->workspace_id,
    );
    my $pages = $sth->fetchall_arrayref();
    return map { $_->[0] } @$pages;
}

=head2 $pages->all_ids_newest_first()

Returns a list of all the page revision ids
sorted in reverse date order.

=cut

sub all_ids_newest_first {
    my $self = shift;
    return $self->all_ids;
}

=head2 $pages->all_ids_locked()

Returns a list of all page_id's which are currently locked.

=cut 

sub all_ids_locked {
    my $self = shift;
    my $t = time_scope 'all_locked';
    my $sth = sql_execute(<<EOT,
SELECT page_id 
    FROM page
    WHERE workspace_id = ?
    AND locked = 't'
    ORDER BY last_edit_time DESC
EOT
        $self->hub->current_workspace->workspace_id,
    );
    my $pages = $sth->fetchall_arrayref();
    return map { $_->[0] } @$pages;
}

sub all_newest_first {
    my $self = shift;
    my $t = time_scope 'all_newest_first';
    return map {$self->new_page($_)} 
      $self->all_ids_newest_first;
}

sub all_since {
    my $self = shift;
    my $minutes = shift;
    my $active_only = ((shift) ? "AND deleted = false" : '');

    my $t = time_scope 'all_since';
    my $sth = sql_execute(<<EOT,
SELECT page_id 
    FROM page
    WHERE workspace_id = ?
        AND last_edit_time > ('now'::timestamptz - ?::interval)
        $active_only
    ORDER BY last_edit_time DESC
EOT
        $self->hub->current_workspace->workspace_id,
        "$minutes minutes",
    );
    my $pages = $sth->fetchall_arrayref();
    return map { $self->new_page($_->[0]) } @$pages;
}

sub all_at_or_after {
    my $self = shift;
    my $after_epoch = shift;
    my $active_only = ((shift) ? "AND deleted = false" : '');

    my $t = time_scope 'all_at_or_after';
    my $dt = DateTime->from_epoch(epoch => $after_epoch);
    my $sth = sql_execute(<<EOT,
SELECT page_id 
    FROM page
    WHERE workspace_id = ?
        AND last_edit_time >= ?::timestamptz
        $active_only
    ORDER BY last_edit_time DESC
EOT
        $self->hub->current_workspace->workspace_id,
        sql_format_timestamptz($dt),
    );
    my $pages = $sth->fetchall_arrayref();
    return map { $self->new_page($_->[0]) } @$pages;
}

sub random_page {
    my $self = shift;
    my $t = time_scope 'random_page';
    my $sth = sql_execute(<<EOT,
SELECT page_id 
    FROM page
    WHERE workspace_id = ?
      AND deleted = false
    ORDER BY RANDOM()
    LIMIT 1
EOT
        $self->hub->current_workspace->workspace_id,
    );
    my $pages = $sth->fetchall_arrayref();
    return (@$pages ? $self->new_page($pages->[0][0]) : undef );
}

sub name_to_title { $_[1] }

sub id_to_uri { $_[1] }

# REVIEW: Probably a class Method
sub title_to_uri {
    my $self = shift;
    $self->uri_escape(shift);
}

sub show_mouseover {
    my $self = shift;
    return $self->{show_mouseover} if defined $self->{show_mouseover};
    $self->{show_mouseover} = 
      $self->hub->preferences->new_for_user( $self->hub->current_user )->mouseover_length->value;
}

sub title_to_disposition {
    my $self = shift;
    my $page_name = shift;
    my $page = $self->new_from_name($page_name);

    return unless $page;

    return ('title="[' . loc("click to create page") . ']" class="incipient"', 
            "action=display;is_incipient=1;page_name=".
            $self->uri_escape($page_name),
           ) unless $page->active;

    my $disposition = '';
    if ($self->show_mouseover) {
        my $preview = $page->summary;
        $disposition = qq|title="$preview"|;
    }

    return ($disposition, $page->uri);
}

sub current_id {
    my $self = shift;
    my $page_name = 
      $self->hub->cgi->page_name ||
      $self->hub->current_workspace->title;
    Socialtext::String::title_to_id($page_name);
}

sub unset_current {
    my $self = shift;
    $self->{current} = undef;
}

sub new_page {
    my $self = shift;
    my $t = time_scope 'pages_new_page';
    Socialtext::Page->new(hub => $self->hub, id => shift);
}

sub new_from_name {
    my $self = shift;
    my $page_name = shift;
    my $id = Socialtext::String::title_to_id($page_name);
    my $page = $self->new_page($id);
    return unless $page;
    $page->title($self->name_to_title($page_name));
    return $page;
}

# This avoids problems in new_from_name wherein the title gets
# set to the URI, not the Subject of the page, even if the page
# already exists.
sub new_from_uri {
    my $self = shift;
    my $uri  = shift;

    my $page = Socialtext::Page->new(
        hub => $self->hub,
        id  => Socialtext::String::title_to_id($uri) );

    die("Invalid page URI: $uri") unless $page;

    my $return_id = Socialtext::String::title_to_id($page->title);
    $page->title( $uri ) unless $return_id eq $uri;

    return $page;
}

sub new_page_from_any {
    my $self = shift;
    my $any = shift;
    my $page = Socialtext::Page->new(hub => $self->hub, id => '_');
    $page->metadata($page->new_metadata('_'));
    $page->load($any);
    $page->id(Socialtext::String::title_to_id($page->metadata->Subject));
    return $page;
}

sub new_page_from_file {
    my $self = shift;
    $self->new_page_from_any(shift);
}

sub new_page_title {
    my $self = shift;
    my @months = qw(January February March April May June
        July August September October November December
    );

    my ($sec, $min, $hour, $mday, $mon) = 
      gmtime(time + $self->hub->timezone->timezone_seconds);

    my $ampm = 'am';
    $ampm = 'pm'  if ($hour > 11);
    $hour -= 12 if ($hour > 12);
    $hour = 12 if ($hour == 0);

    my $user = $self->hub->current_user;

    my $title =
        sprintf("%s, %s %s, %d:%02d$ampm", 
                $user->best_full_name,
                $months[$mon], $mday, $hour, $min
               );

    my $current_workspace = $self->hub->current_workspace->name;

    my $x = 2;
    while ( $self->page_exists_in_workspace( $title, $current_workspace ) ) {
        $title =~ s/(?: - \d+)|\z$/ - $x/;
        $x++;
    }

    return $title;
}

=head2 create_new_page

Create a "new page". That is, a page with a title that is automaticall
generated. A scabrous thing, but necessary in the current UI.

Returns a L<Socialtext::Page> object.

=cut
sub create_new_page {
    my $self = shift;

    # See comment in display() about using this error_type.
    $self->hub->require_permission(
        permission_name => 'edit',
        error_type      => 'login_to_edit',
    );

    my $page = $self->new_from_name( $self->new_page_title );

    return $page;
}

sub page_exists_in_workspace {
    my $self       = shift;
    my $page_title = shift;
    my $ws_name    = shift;
    my $page       = $self->page_in_workspace( $page_title, $ws_name );

    return ( $page ) ? 1 : 0;
}

sub page_in_workspace {
    my $self       = shift;
    my $page_title = shift;
    my $ws_name    = shift;
    my $main       = Socialtext->new();

    $main->load_hub(
        current_user      => Socialtext::User->SystemUser(),
        current_workspace => Socialtext::Workspace->new( name => $ws_name ),
    );
    $main->hub()->registry()->load();

    my $page = $main->hub->pages->new_from_name($page_title);
    return ($page->metadata->Revision and $page->active) ? $page : undef;
}

my %in_progress = ();
sub _render_in_workspace {
    my ($self, $page_id, $ws, $callback) = @_;

    my $page_key = $ws->workspace_id . ":$page_id";
    return if (exists $in_progress{$page_key});
    $in_progress{$page_key} = 1;
    scope_guard { delete $in_progress{$page_key} };

    my $main;
    my $hub = $self->hub;
    if ($ws->workspace_id ne $self->hub->current_workspace->workspace_id) {
        my $original_hub = $hub;
        ($main, $hub) = $ws->_main_and_hub($original_hub->current_user);

        my $link_dictionary = $original_hub->viewer->link_dictionary->clone;
        $link_dictionary->free($link_dictionary->interwiki);
        $hub->viewer->link_dictionary($link_dictionary);
    }

    $callback->($hub->pages->new_page($page_id));
    return; # make above call void context
}

sub html_for_page_in_workspace {
    my $self = shift;
    my $page_id        = shift;
    my $workspace_name = shift;

    my $ws = Socialtext::Workspace->new(name => $workspace_name);
    my $html;
    $self->_render_in_workspace($page_id, $ws, sub {
        my $page = shift;
        $html = $page->to_html_or_default;
    });
    return $html;
}

# Grab the wikitext from a spreadsheet and put it in a page object.
# Used by BackLinksPlugin.
sub page_with_spreadsheet_wikitext {
    my $self = shift;
    my $page = shift;

    my $new = $self->hub->pages->new_from_name($page->id);
    my $wikitext = '';
    my $text = $new->content;

    # TODO: use Socialtext::Sheet
    OUTER: while (1) {
        $text =~ s/.*?\n--SocialCalcSpreadsheetControlSave\n//s
            or last; 
        $text =~ s/(.*?)\n--SocialCalcSpreadsheetControlSave\n//s;
        my $section = $1;
        my @parts = ($section =~ /part:(.*)/g);
        while (my $part = shift @parts) {
            last if $part eq 'sheet';
            $text =~ s/.*?\n--SocialCalcSpreadsheetControlSave\n//s
                or last OUTER;
        }
        $text =~ s/(.*?)\n--SocialCalcSpreadsheetControlSave\n//s;
        $section = $1 or last;
        $section =~ /^valueformat:(\d+):text-wiki$/m or last;
        my $num = $1;
        my @lines = ($section =~ /\ncell:.+?:.+?:(.*?):.*tvf:$num/g);
        $wikitext = join "\n", map {
            s/\\c/:/g;
            s/\\n/\n/g;
            s/\\t/\t/g;
            "$_\n";
        } @lines;
        last;
    }
    $new->content($wikitext);
    return $new;
}

################################################################################
package Socialtext::Pages::Formatter;

use base 'Socialtext::Formatter';

sub wafl_classes {
    my $self = shift;
    map {
        s/^File$/Socialtext::Pages::Formatter::File/;
        s/^Image$/Socialtext::Pages::Formatter::Image/;
        $_
    } $self->SUPER::wafl_classes(@_);
}

################################################################################
package Socialtext::Pages::Formatter::Image;

use Socialtext::Formatter::WaflPhrase;
use base 'Socialtext::Formatter::Image';

sub html {
    my $self = shift;
    my ($workspace_name, $page_title, $image_name, $page_id, $page_uri) = 
      $self->parse_wafl_reference;
    return $self->syntax_error unless $image_name;
    return qq{<img src="cid:$image_name" />};
}

################################################################################
package Socialtext::Pages::Formatter::File;

use Socialtext::Formatter::WaflPhrase;
use base 'Socialtext::Formatter::File';

sub html {
    my $self = shift;
    my (undef, undef, $file_name) = $self->parse_wafl_reference;
    my $link = $self->SUPER::html(@_);
    $link =~ s/ target="_blank"//;
    $link =~ s/ href="[^"]+"/ href="cid:$file_name"/i;
    return $link;
}

1;

