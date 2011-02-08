package Socialtext::Page::TablePopulator;
# @COPYRIGHT@
use strict;
use warnings;
use Email::Valid;
use Socialtext::Workspace;
use Socialtext::Paths;
use Socialtext::Hub;
use Socialtext::User;
use Socialtext::File;
use Socialtext::AppConfig;
use Socialtext::Page::Legacy;
use Socialtext::PageRevision;
use Socialtext::Timer qw/time_scope/;
use Socialtext::SQL qw(get_dbh :exec :txn);
use Fatal qw/opendir closedir chdir open/;
use Cwd   qw/abs_path/;
use DateTime;

sub new {
    my $class = shift;
    my %opts  = @_;
    die "workspace is mandatory!" unless $opts{workspace_name};

    my $self = \%opts;
    bless $self, $class;

    $self->{workspace}
        = Socialtext::Workspace->new( name => $opts{workspace_name} );
    die "No such workspace $opts{workspace_name}\n"
        unless $self->{workspace};

    die "data_dir is a required option" unless $self->{data_dir};
    die "No such directory $self->{data_dir}"
        unless -d $self->{data_dir};

    $self->{old_name} ||= $self->{workspace_name};
    $self->{workspace_data_dir} = "$self->{data_dir}/data/$self->{old_name}";
    die "No such workspace directory $self->{workspace_data_dir}"
        unless -d $self->{workspace_data_dir};
    $self->{workspace_plugin_dir}
        = "$self->{data_dir}/plugin/$self->{old_name}";
    $self->{workspace_user_dir}
        = "$self->{data_dir}/user/$self->{old_name}";

    return $self;
}

sub populate {
    my $self = shift;
    my %opts = @_;
    my $recreate = $opts{recreate};
    my $workspace = $self->{workspace};
    my $workspace_name = $self->{workspace_name};

    eval { sql_txn {
        # Start a transaction, and delete everything for this workspace.
        # if we're recreating the workspace from scratch, clean it out *first*
        if ($recreate) {
            sql_execute(
                'DELETE FROM page WHERE workspace_id = ?',
                $workspace->workspace_id,
            );
            sql_execute(
                'DELETE FROM page_revision WHERE workspace_id = ?',
                $workspace->workspace_id,
            );
            sql_execute(
                'DELETE FROM breadcrumb WHERE workspace_id = ?',
                $workspace->workspace_id,
            );
        }

        # Grab all the Pages in the Workspace, figure out which ones we need
        # to add to the DB, then add them all.
        my $workspace_dir = $self->{workspace_data_dir};
        my $hub = $self->{hub}
            = Socialtext::Hub->new( current_workspace => $workspace );
        chdir $workspace_dir;
        opendir(my $dfh, $workspace_dir);
        my @pages;
        my @page_tags;
      PAGE:
        while (my $dir = readdir($dfh)) {
            next PAGE unless -d $dir;
            next PAGE if $dir =~ m/^\./;

            # Ignore really old pages that have invalid page_ids
            next PAGE unless Socialtext::Encode::is_valid_utf8($dir);

            # Fix up relative links in the filesystem
            eval { fix_relative_page_link($dir) };
            if ($@) {
                warn "Error fixing relative link: $@";
                next PAGE;
            }

            # Get all the data we want on a page
            my $workspace_id = $workspace->workspace_id;

            my $page = eval {
                $self->load_page_metadata($workspace_dir, $dir);
            };
            if ($@) {
                warn "Error populating $workspace_name, skipping $dir: $@";
                next PAGE;
            }

            # Skip this page if it already exists in the DB
            my $page_exists_already = page_exists_in_db(
                workspace_id => $workspace_id,
                page_id      => $page->{page_id},
            );
            next PAGE if $page_exists_already;

            # Add this page (and its tags) to the list of things to add to the
            # DB. NOTE these are in the same column-order as the actual table.
            push @pages, [
                $workspace_id, $page->{page_id}, $page->{name},
                $page->{last_editor_id}, $page->{last_edit_time},
                $page->{creator_id},     $page->{create_time},
                $page->{revision_id},
                $page->{revision_count},
                $page->{revision_num},
                $page->{page_type}, $page->{deleted},
                $page->{summary}, $page->{edit_summary},
                $page->{locked},
                $page->{tags},
                $page->{views},
            ];

            my %tags;
            for my $t (grep { length } @{ $page->{tags} }) {
                next if $tags{lc($t)}++; # avoid duplicate tags
                push @page_tags, [ $workspace_id, $page->{page_id}, $t ];
            }
        }
        closedir($dfh);

        # Now add all those pages and tags to the database
        add_to_db('page', \@pages);
        add_to_db('page_tag', \@page_tags);

        $self->load_breadcrumbs();
    }};
    die "Error during populate of $workspace_name: $@" if $@;
}

sub load_page_metadata {
    my $self   = shift;
    my $ws_dir = shift;
    my $dir    = shift;

    my $ws_id = $self->{workspace}->workspace_id;
    $self->load_revision_metadata($ws_dir, $dir);
    my $sth;

    # Start with latest revision fields.  This *should* exclude "body".
    $sth = sql_execute(q{
        SELECT }.Socialtext::PageRevision::COLUMNS_STR.q{
          FROM page_revision
         WHERE workspace_id = ? AND page_id = ?
         ORDER BY revision_id DESC
         LIMIT 1
    }, $ws_id, $dir);
    my $page = $sth->fetchrow_hashref();

    # and creation stats
    $sth = sql_execute(q{
        SELECT editor_id AS creator_id, edit_time AS create_time
          FROM page_revision
         WHERE workspace_id = ? AND page_id = ?
         ORDER BY revision_id ASC
         LIMIT 1
    }, $ws_id, $dir);
    @$page{qw(creator_id create_time)} = $sth->fetchrow_array();

    # and a revision tally
    $page->{revision_count} = sql_singlevalue(q{
        SELECT count(1) AS revision_count
          FROM page_revision
         WHERE workspace_id = ? AND page_id = ?
    }, $ws_id, $dir);

    # Finally, attempt to load the COUNTER file for this page
    my $counter_file = "$self->{workspace_plugin_dir}/counter/$dir/COUNTER";
    $page->{views} = -e $counter_file ? read_counter($counter_file) : 0;

    $page->{revision_count} ||= 0;
    $page->{summary} //= '';
    $page->{edit_summary} //= '';

    $page->{last_editor_id} = delete $page->{editor_id};
    $page->{last_edit_time} = delete $page->{edit_time};

    delete $page->{body_length};

    return $page;
}

my $page_rev_insert = do {
    my $cols_str = join(',', 'body', Socialtext::PageRevision::COLUMNS());
    my $ph = '?'; # body
    $ph .= ',?' x scalar(Socialtext::PageRevision::COLUMNS());
    qq{INSERT INTO page_revision ($cols_str) VALUES ($ph)};
};

sub load_revision_metadata {
    my $self   = shift;
    my $ws_dir = shift;
    my $pg_dir = shift;

    my $dbh = get_dbh();
    my $sth = $dbh->prepare_cached($page_rev_insert) or die $dbh->errmsg;

    opendir(my $dfh, "$ws_dir/$pg_dir");
    REV: while (my $file = readdir($dfh)) {
        next unless $file =~ m/^\d+\.txt$/;
        $file = "$ws_dir/$pg_dir/$file";
        next REV if -l $file;
        next REV unless -f $file;

        # Ignore really old pages that have invalid page_ids
        next REV unless Socialtext::Encode::is_valid_utf8($file);
        eval {
            (my $revision_id = $file) =~ s#.+/(.+)\.txt$#$1#;
            my $pagemeta = fetch_metadata($file);
            my $body_ref = Socialtext::Page::Legacy::read_and_decode_file(
                $file, 1, 1); # "return content as ref"

            my $tags = $pagemeta->{Category} || [];
            $tags = [$tags] unless ref($tags);

            my $subject = $pagemeta->{Subject} || '';
            if (ref($subject)) { # Handle bad duplicate headers
                $subject = shift @$subject;
            }
            my $summary = $pagemeta->{Summary} || '';
            if (ref($summary) eq 'ARRAY') {
                # work around a bug where a page has 2 Summary revisions.
                $summary = $summary->[-1];
            }

            my %cols = (
                workspace_id => $self->{workspace}->workspace_id,
                page_id => $pg_dir,
                body_length => length($$body_ref),
                revision_id => $revision_id,
                revision_num => $pagemeta->{Revision}||1,
                name => $subject,
                editor_id => editor_to_id($pagemeta->{From}),
                edit_time => $pagemeta->{Date},
                page_type => $pagemeta->{Type}||'wiki',
                deleted => (($pagemeta->{Control} || '') eq 'Deleted') ? 1 : 0,
                summary => $summary,
                edit_summary => $pagemeta->{'Revision-Summary'},
                locked => $pagemeta->{Locked}||0,
                tags => $tags,
            );

            local $dbh->{RaiseError} = 1;
            my $n = 1;
            $sth->bind_param($n++, $$body_ref, {pg_type => DBD::Pg::PG_BYTEA});
            for my $col (Socialtext::PageRevision::COLUMNS()) {
                $sth->bind_param($n++, $cols{$col});
            };
            $sth->execute;
            die "failed to insert $revision_id" unless $sth->rows == 1;
        };
        if ($@) {
            warn "Error parsing revision $ws_dir/$pg_dir/$file: $@, skipping\n";
        }
    }
    closedir($dfh);
}

# This method was copied from Socialtext::Page, to remove a dependency
# should that module change in the future.
# (One less thing to think about then.)
sub parse_headers {
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
    return $metadata;
}

sub add_to_db {
    my $table = shift;
    my $rows = shift;
    my $t = time_scope "add_to_db $table";

    unless (@$rows) {
        warn "No rows to add to $table.\n";
        return;
    }

    my $dbh = get_dbh();

    my $ph = '?,' x scalar @{ $rows->[0] }; chop $ph;
    $table = $dbh->quote_identifier($table);
    my $sth = $dbh->prepare_cached(qq{INSERT INTO $table VALUES ($ph)})
        or die $dbh->errstr;
    my $row;
    for $row (@$rows) {
        $sth->execute(@$row)
            or die "Error during execute - (INSERT INTO $table) - bindings=("
            . join(', ', @$row) . ') - '
            . $sth->errstr;
    }
}

sub page_exists_in_db {
    my %opts = @_;
    my $ws_id   = $opts{workspace_id} || die "workspace_id is required";
    my $page_id = $opts{page_id}      || die "page_id is required";

    my $t = time_scope 'page_exists_in_db';
    my $exists_already = sql_singlevalue( q{
        SELECT true
          FROM page
         WHERE workspace_id = ?
           AND page_id = ?
        }, $ws_id, $page_id
    );
    return defined $exists_already ? 1 : 0;
}

sub load_original_revision {
    my $page_dir = shift;

    opendir my $dir, $page_dir or die "Couldn't open $page_dir";
    my @ids = grep defined, map { /(\d+)\.txt$/; $1; } readdir $dir;
    closedir $dir;

    @ids = sort @ids;
    my $orig_rev = shift @ids;

    my $file = "$page_dir/$orig_rev.txt";
    die "$file does not exist!" unless -e $file;
    my $orig_metadata = fetch_metadata($file);
    return (scalar(@ids), $orig_metadata);
}

sub fetch_metadata {
    my $file = shift;

    # Ignore non-UTF-8 warnings
    local $SIG{__WARN__} = sub {
        my $warning = shift;
        if ($warning =~ m/\Qdoesn't seem to be valid utf-8\E/ or
            $warning =~ m/\QTreating as iso-8859-1\E/) {
        }
        else {
            warn "\n\n$warning\n";
        }
    };

    my $content = Socialtext::Page::Legacy::read_and_decode_file($file);
    return parse_headers($content);
}

{
    my %userid_cache;

    # This code inspired by Socialtext::Page::last_edited_by
    sub editor_to_id {
        my $email_address = shift || '';
        unless ( $userid_cache{ $email_address } ) {
            # We have some very bogus data on our system, so we need to
            # be very cautious.
            unless ( Email::Valid->address($email_address) ) {
                my ($name) = $email_address =~ /([\w-]+)/;
                $name = 'unknown' unless defined $name;
                $email_address = $name . '@example.com';
            }

            # Load or create a new user with the given email.
            # Email addresses are always written to disk, even for ldap users.
            my $user;
            eval {
                $user = Socialtext::User->new(email_address => $email_address);
            };
            unless ($user) {
                warn "Creating user account for '$email_address'\n";
                eval {
                    $user = Socialtext::User->create(
                        email_address => $email_address,
                        username      => $email_address,
                    );
                };
                $user ||= Socialtext::User->SystemUser();
            }

            $userid_cache{ $email_address } = $user->user_id;
        }
        return $userid_cache{ $email_address };
    }
}


sub find_current_revision {
    my $dir = shift;

    my $page_link_name = "$dir/index.txt";

    my $current_revision_file = ( -f $page_link_name )
        ? readlink( $page_link_name )
        : Socialtext::File::newest_directory_file( $dir );

    die "Couldn't find revision page for $page_link_name, skipping."
        unless $current_revision_file;

}

sub fix_relative_page_link {
    my $dir = shift;

    my $current_revision_file = find_current_revision( $dir );

    unless ($current_revision_file =~ m#^/#) {
        my $abs_page = abs_path("$dir/$current_revision_file");
        die "Could not find symlinked page ($abs_page)"
            unless -f $abs_page;
        Socialtext::File::safe_symlink($abs_page, "$dir/index.txt");
    }
}

sub read_counter {
    my $file = shift;
    my $contents = Socialtext::File::get_contents($file);
    my (undef, $count) = split "\n", $contents;
    return $count;
}

sub load_breadcrumbs {
    my $self  = shift;
    my $ws_id = $self->{workspace}->workspace_id;

    my $ws_user_dir = $self->{workspace_user_dir};
    return unless -d $ws_user_dir;

    # The .trail files do not contain dates, so we will sythesize dates
    # to provide order. We will start at midnight of today and add a second
    # for each breadcrumb
    my $date = DateTime->now;
    $date->set_hour(0);
    $date->set_minute(0);

    my @breadcrumbs;
    opendir(my $dfh, $ws_user_dir);
    while (my $user_dir = readdir($dfh)) {
        next unless -d "$ws_user_dir/$user_dir";
        next if $user_dir =~ m/^\./;
        my $trail = "$ws_user_dir/$user_dir/.trail";
        next unless -e $trail;

        my $user = Socialtext::User->new(email_address => $user_dir);
        next unless $user;

        my @page_ids =
            map { Socialtext::String::title_to_id($_) }
                split "\n", Socialtext::File::get_contents_utf8($trail);

        my $i = 0;
        for my $id (@page_ids) {
            $date->set_second($i++);
            push @breadcrumbs, [ $user->user_id, $ws_id, $id, $date->iso8601 ];
        }
    }
    add_to_db('breadcrumb', \@breadcrumbs) if @breadcrumbs;
}


1;
