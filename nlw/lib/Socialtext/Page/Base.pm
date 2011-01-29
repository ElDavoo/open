# @COPYRIGHT@
package Socialtext::Page::Base;

=head1 NAME

Socialtext::Page::Base - Base class for page objects

This code is inherited by old-style Socialtext::Page objects
AND new-style Socialtext::Model::Page objects.

=cut

use strict;
use warnings;
use Socialtext::Formatter::AbsoluteLinkDictionary;
use Socialtext::Permission 'ST_READ_PERM';
use Socialtext::File;
use Socialtext::l10n qw(loc);
use Socialtext::Log qw/st_log/;
use Socialtext::Timer qw/time_scope/;
use Socialtext::SQL qw/sql_singlevalue sql_singleblob sql_execute/;
use Socialtext::l10n qw(loc);
use Socialtext::String;
use Digest::SHA1 'sha1_hex';
use Carp ();
use URI::Escape qw/uri_escape_utf8/;

our $CACHING_DEBUG = 0;
our $DISABLE_CACHING = 0;

=head2 to_absolute_html($content)

Turn the provided $content or the content of this page into html
with the URLs formatted as fully qualified links.

As written this code modifies the L<Socialtext::Formatter::LinkDictionary>
in the L<Socialtext::Formatter::Viewer> used by the current hub. This
means that unless this hub terminates, further formats in this
session will be absolute. This is probably a bug.

=cut

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

sub exists {
    my $self = shift;
    $self->id && $self->all_revision_ids;
}

sub all {
    my $self = shift;
    return (
        page_uri => $self->uri,
        page_title => $self->title,
        page_title_uri_escaped => uri_escape_utf8($self->title),
        revision_id => $self->revision_id,
    );
}

=head2 $page->all_revision_ids()

Returns a sorted list of all the revision ids for a given page.

In scalar context, returns only the count and doesn't bother sorting.

=cut

sub all_revision_ids {
    my $self = shift;

    if (!wantarray) {
        return sql_singlevalue(
            'SELECT count(*) FROM page_revision
              WHERE workspace_id = ?
                AND page_id = ?',
            $self->hub->current_workspace->workspace_id,
            $self->id,
        );
    }
    my $sth = sql_execute(
        'SELECT revision_id FROM page_revision
          WHERE workspace_id = ?
            AND page_id = ?
          ORDER BY revision_id ASC
        ',
        $self->hub->current_workspace->workspace_id,
        $self->id,
    );
    return (
        map { $_->[0] } @{ $sth->fetchall_arrayref }
    );
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

sub _page_cache_basename {
    my $self = shift;
    my $cache_dir = $self->_cache_dir or return;
    return "$cache_dir/" . $self->id . '-' . ($self->revision_id || 'no-revid');
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

=head2 revision_id( $id )

If $id is present, sets the revision_id of this object. This is the
way to retrieve an older revision.

If $id is not present, returns the revision_id of the page object.

Debates on what a revision_id is left as an exercise for the 
reader. See also L<Socialtext::PageMeta> and its Revision field.

=cut
sub revision_id {
    my $self = shift;
    if (@_) {
        $self->{revision_id} = shift;
        return $self->{revision_id};
    }
    $self->assert_revision_id;
    return $self->{revision_id};
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

    $revision_id = sql_singlevalue(
        'SELECT revision_id FROM page_revision
          WHERE workspace_id = ?
            AND page_id = ?
          ORDER BY revision_id DESC
          LIMIT 1
        ', $self->hub->current_workspace->workspace_id,
        $self->id,
    );

    $self->revision_id($revision_id);
}

=head2 $page->get_units(%matches)

Parse the wikitext of a page to find the units named in matches
and push information about each matched unit onto a list that
is returned as a reference.

%matches is made up of key value pairs. The key is the name of a 
valid L<Socialtext::Formatter::Unit>. The value is a 
subroutine that returns a reference to a hash that may
contain anything. The assumption is that it will contain
information about the unit. See get_headers and get_sections
for examples.

=cut 

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

sub content_or_default {
    my $self = shift;
    return $self->is_spreadsheet
        ? ($self->content || loc('Creating a New Spreadsheet...') . '   ')
        : ($self->content || loc('Replace this text with your own.') . '   ');
}

=head2 $page->app_uri()

This builds a uri historically used in the app. YMMV

=cut

sub app_uri {
    my $self = shift;
    return $self->full_uri if $self->exists;

    return $self->hub->current_workspace->uri
        . Socialtext::AppConfig->script_name . "?"
        . $self->id;
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

sub content {
    my $self = shift;
    return $self->{content} = shift if @_;
    return $self->{content} if defined $self->{content};
    $self->load_content;
    return $self->{content} || '';
}

sub load_content {
    my $self = shift;
    my $rev_id = $self->revision_id;
    return '' unless $rev_id;
    sql_singleblob(\$self->{content},
        'SELECT body FROM page_revision
          WHERE workspace_id = ?
            AND page_id = ?
            AND revision_id = ?
        ', $self->hub->current_workspace->workspace_id, $self->id, $rev_id,
    );
    $self->content('') unless defined $self->{content};
    return $self;
}

sub html_escaped_categories {
    my $self = shift;
    return map { Socialtext::String::html_escape($_) } $self->categories_sorted;
}

1;
