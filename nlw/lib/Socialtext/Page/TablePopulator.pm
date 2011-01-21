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
use Socialtext::SQL qw(get_dbh :exec :txn);
use Fatal qw/opendir closedir chdir open/;
use Cwd   qw/abs_path/;

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

    $self->{workspace_dir} ||= 
            Socialtext::Paths::page_data_directory($opts{workspace_name});
    die "No such workspace directory $self->{workspace_dir}"
        unless -d $self->{workspace_dir};

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
        }

        # Grab all the Pages in the Workspace, figure out which ones we need
        # to add to the DB, then add them all.
        my $workspace_dir = $self->{workspace_dir};
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
            my ($page, $last_editor, $first_editor);
            my $workspace_id = $workspace->workspace_id;

            eval {
                $page = $self->load_page_metadata($workspace_dir, $dir);
                $last_editor  = editor_to_id($page->{last_editor});
                $first_editor = editor_to_id($page->{creator_name});
            };
            if ($@) {
                warn "Error populating $workspace_name: $@";
                next PAGE;
            }

            # Skip this page if it already exists in the DB
            my $page_exists_already = page_exists_in_db(
                workspace_id => $workspace_id,
                page_id      => $page->{page_id},
            );
            next PAGE if $page_exists_already;

            # Add this page (and its tags) to the list of things to add to the
            # DB.
            push @pages, [
                $workspace_id,        $page->{page_id}, $page->{name},
                $last_editor,         $page->{last_edit_time},
                $first_editor,        $page->{create_time},
                $page->{revision_id}, $page->{revision_count},
                $page->{revision_num},
                $page->{type}, $page->{deleted}, $page->{summary},
                $page->{edit_summary} || '',
                $page->{locked} || 0,
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
    }};
    die "Error during populate of $workspace_name: $@" if $@;
}

sub load_page_metadata {
    my $self   = shift;
    my $ws_dir = shift;
    my $dir    = shift;

    $self->load_revision_metadata($ws_dir, $dir);

    my $current_revision_file = find_current_revision( $dir );
    my $pagemeta = fetch_metadata($current_revision_file);

    my $revision_id = $current_revision_file;
    $revision_id =~ s#.+/(.+)\.txt$#$1#;

    my $tags = $pagemeta->{Category} || [];
    $tags = [$tags] unless ref($tags);

    my $subject = $pagemeta->{Subject} || '';
    if (ref($subject)) { # Handle bad duplicate headers
	$subject = shift @$subject;
    }
    my $summary = $pagemeta->{Summary} || '';
    unless ($summary) {
        my $p = Socialtext::Page->new( 
            hub => $self->{hub}, id => $dir,
        );
        $summary = $p->preview_text;
        if ($p->can('_store_preview_text')) {
            # Store the preview text back in the file to save work for later
            $p->_store_preview_text($summary);
        }
    }
    if (ref($summary) eq 'ARRAY') {
        # work around a bug where a page has 2 Summary revisions.
        $summary = $summary->[-1];
    }

    my ($num_revisions, $orig_page) = load_original_revision($dir);
    # This is special case for any extremely bad data on the system
    $orig_page->{From} ||= $pagemeta->{From};
    $orig_page->{Date} ||= $pagemeta->{Date};

    my $last_edit_time = $pagemeta->{Date};
    unless ($last_edit_time) {
        # Proper thing to do here is to read the timestamp of the file
        # and convert that into a date string
        die "No Date found for $dir, skipping\n";
    }

    return {
        page_id => $dir,
        name => $subject,
        last_editor => $pagemeta->{From},
        last_edit_time => $last_edit_time,
        revision_id => $revision_id,
        revision_count => $num_revisions,
        revision_num => $pagemeta->{Revision} || 1,
        type => $pagemeta->{Type} || 'wiki',
        deleted => ($pagemeta->{Control} || '') eq 'Deleted' ? 1 : 0,
        tags => $tags,
        summary => $summary,
        creator_name => $orig_page->{From},
        create_time => $orig_page->{Date},
    };
}

sub load_revision_metadata {
    my $self   = shift;
    my $ws_dir = shift;
    my $pg_dir = shift;

    my @revisions;
    opendir(my $dfh, "$ws_dir/$pg_dir");
    REV: while (my $file = readdir($dfh)) {
        $file = "$ws_dir/$pg_dir/$file";
        next REV if -l $file;
        next REV unless -f $file;

        # Ignore really old pages that have invalid page_ids
        next REV unless Socialtext::Encode::is_valid_utf8($file);
        my $pagemeta = fetch_metadata($file);
        (my $revision_id = $file) =~ s#.+/(.+)\.txt$#$1#;
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

        push @revisions, [
            $self->{workspace}->workspace_id,
            $pg_dir,
            $revision_id,
            $pagemeta->{Revision} || 1,
            $subject,
            editor_to_id($pagemeta->{From}),
            $pagemeta->{Date},
            $pagemeta->{Type} || 'wiki',
            ($pagemeta->{Control} || '') eq 'Deleted' ? 1 : 0,
            $summary,
            $pagemeta->{RevisionSummary} || '',
            0,
            $tags,
            Socialtext::Page::Legacy::read_and_decode_file($file, 'content'),
        ];
    }
    closedir($dfh);

    add_to_db('page_revision', \@revisions);
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

    unless (@$rows) {
        warn "No rows to add to $table.\n";
        return;
    }

    my $dbh = get_dbh();

    my $vals = join ',', map { '?' } @{ $rows->[0] };
    my $sth = $dbh->prepare(<<EOT);
INSERT INTO $table VALUES ($vals);
EOT
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

1;
