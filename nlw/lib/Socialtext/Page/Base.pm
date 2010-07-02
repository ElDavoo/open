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
use Socialtext::Log qw/st_log/;
use Socialtext::Timer qw/time_scope/;
use Socialtext::SQL qw/sql_singlevalue/;
use Carp ();
use Carp qw/cluck/;

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
    my $content = @_ ? shift : $self->content;
    my $page = shift;
    $content = '' unless defined $content;

    return $self->hub->pluggable->hook('render.sheet.html', \$content, $self)
        if $self->is_spreadsheet;

    # Look for cached HTML
    my $q_file = $self->_question_file;
    if ($q_file and -e $q_file) {
        my $q_str = Socialtext::File::get_contents($q_file);
        my $a_str = $self->_questions_to_answers($q_str);
        my $cache_file = $self->_answer_file($a_str);
        my $cache_file_exists = $cache_file && -e $cache_file;
        my $users_changed
            = $self->_users_modified_since($q_str, (stat($cache_file))[9])
            if $cache_file_exists;
        if ($cache_file_exists and !$users_changed) {
            my $t = time_scope('wikitext_HIT');
            $self->{__cache_hit}++;
            return scalar Socialtext::File::get_contents_utf8($cache_file);
        }

        my $t = time_scope('wikitext_MISS');
        my $html = $self->hub->viewer->process($content, $page);
        if (defined $a_str) {
            # cache_file may be undef if the answer string was too long.
            Socialtext::File::set_contents_utf8($cache_file, $html) if $cache_file;
            return $html;
        }
        # Our answer string was invalid, so we'll need to re-generate the Q file
        # We will pass in the rendered html to save work
        return ${ $self->_cache_html(\$html) };
    }

    my $html_ref = $self->_cache_html;
    return $$html_ref;
}

sub _users_modified_since {
    my $self = shift;
    my $q_str = shift;
    my $cached_at = shift;

    my @found_users;
    my @user_ids;
    while ($q_str =~ m/(?:^|-)u(\d+)(?:-|$)/g) {
        push @user_ids, $1;
    }
    return 0 unless @user_ids;

    my $user_placeholders = join ',', map {'?'} @user_ids;
    my $updated_after_cache = sql_singlevalue(qq{
        SELECT 1 FROM users
         WHERE user_id IN ($user_placeholders)
           AND last_profile_update >
                'epoch'::timestamptz + ? * INTERVAL '1 second'
        }, @user_ids, $cached_at) || 0;

    return 1 if $updated_after_cache;
    return 0;
}

sub _questions_to_answers {
    my $self = shift;
    my $q_str = shift;

    my $t = time_scope('QtoA');
    my $cur_user = $self->hub->current_user;
    my $authz = $self->hub->authz;

    my @answers;
    for my $q (split '-', $q_str) {
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
            my $ok = $user && $user->profile_is_visible_to($cur_user) ? 1 : 0;
            push @answers, "${q}_$ok";
        }
        elsif ($q =~ m/^h(\d+)$/) {
            my $ws = Socialtext::Workspace->new(workspace_id => $1);
            my $ok = $ws && $ws->allows_html_wafl() ? 1 : 0;
            push @answers, "${q}_$ok";
        }
        elsif ($q =~ m/^E(\d+)$/) {
            my $expires_at = $1;
            my $ok = time() < $expires_at ? 1 : 0;
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
            $my_prefs =~ s/-/m/; # - is used as a field separator
            my $ok = $pref_str eq $my_prefs;
            push @answers, "${q}_$ok";
        }
        elsif ($q eq 'null') {
            next;
        }
        else {
            my $ws_name = $self->hub->current_workspace->name;
            st_log->info("Unknown wikitext cache question '$q' for $ws_name/"
                    . $self->id);
            return undef;;
        }
    }
    return join '-', @answers;
}

sub exists {
    my $self = shift;
    -e $self->file_path;
}

sub file_path {
    my $self = shift;
    join '/', $self->database_directory, $self->id;
}

sub directory_path {
    my $self = shift;
    my $id = $self->id
        or Carp::confess( 'No ID for content object' );
    return Socialtext::File::catfile(
        $self->database_directory,
        $id
    );
}

=head2 $page->all_revision_ids()

Returns a sorted list of all the revision filenames for a given page.

In scalar context, returns only the count and doesn't bother sorting.

=cut

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

    my $orig_page = ref($self)->new(hub => $self->hub, id => $page_id);
    $orig_page->revision_id( $orig_id );
    $orig_page->load;
    return $orig_page;
}

sub attachments {
    my $self = shift;

    return @{ $self->hub->attachments->all( page_id => $self->id ) };
}

sub set_mtime {
    my $self = shift;
    my $mtime = shift;
    my $filename = shift;

    (my $dirpath = $filename) =~ s#(.+)/.+#$1#;

    # Several parts of NLW look at the mtime of the page directory
    # to determine the last edit.  So if we don't change the mtimes,
    # notification emails (say) could be sent out.
    utime $mtime, $mtime, $filename 
        or warn "utime $mtime, $filename failed: $!";
    utime $mtime, $mtime, $dirpath 
        or warn "utime $mtime, $dirpath failed: $!";
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
    my $answer_str = shift || '';
    my $base = $self->_page_cache_basename or return;
    my $filename = "$base-$answer_str";
    (my $basename = $filename) =~ s#.+/##;
    return undef if length($basename) > 255;
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
    return $self->assert_revision_id;
}

sub _get_index_file {
    my $self      = shift;
    my $dir       = $self->directory_path;
    my $filename  = "$dir/index.txt";

    return $filename if -f $filename;
    return '' unless my @revisions = $self->all_revision_ids;

    # This is adding some fault-tolerance to the system. If the index.txt file
    # doesn not exist, we're gonna re-create it rather than throw an error.
    my $revision_file = $self->revision_file( pop @revisions ); 
    Socialtext::File::safe_symlink($revision_file => $filename);

    return $filename;
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

1;
