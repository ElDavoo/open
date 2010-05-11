package Socialtext::JobCreator;
# @COPYRIGHT@
use MooseX::Singleton;
use MooseX::AttributeInflate;
use Socialtext::TheSchwartz;
use Socialtext::Search::AbstractFactory;
use Socialtext::SQL qw/:exec/;
use Carp qw/croak/;
use Socialtext::Log qw/st_log/;
use Socialtext::Cache ();
use namespace::clean -except => 'meta';

has_inflated '_client' => (
    is => 'ro', isa => 'Socialtext::TheSchwartz',
    lazy_build => 1,
    handles => qr/(?:list|find|get_server_time|func|move_jobs_by|cancel_job)/,
);

sub insert {
    my $self = shift;
    my $job_class = shift;
    croak 'Job Class is required' unless $job_class;
    my $args = (@_==1) ? shift : {@_};
    $args->{job} ||= {};
    if ($job_class =~ /::Upgrade::/) {
        $args->{job}{priority} ||= -64;
    }
    return $self->_client->insert($job_class => $args);
}

sub index_attachment {
    my $self = shift;
    my $attachment = shift;
    my $search_config = shift;

    my $wksp_id = $attachment->hub->current_workspace->workspace_id;
    my $page_id = $attachment->page->id;
    my $attach_id = $attachment->id;

    return if $attachment->page->is_bad_page_title($page_id);
    return if ($attachment->loaded && $attachment->temporary);

    my %job_args = (
        workspace_id => $wksp_id,
        page_id => $page_id,
        attach_id => $attach_id,
        job => {
            priority => 63,
            coalesce => "$wksp_id-$page_id-$attach_id",
        },
    );

    if ($search_config and $search_config eq 'solr') {
        return; # XXX - turn OFF Solr indexing for attachment content.
        $job_args{job}{coalesce} .= "-solr";
        $job_args{solr} = 1;
    }
    else {
        $job_args{job}{coalesce} .= "-kino";
        $job_args{search_config} = $search_config;
    }
    return $self->insert('Socialtext::Job::AttachmentIndex' => \%job_args);
}

sub index_page {
    my $self = shift;
    my $page = shift;
    my $search_config = shift;
    my %opts = @_;

    return if $page->is_bad_page_title($page->id);

    my @job_ids;

    my @indexers = Socialtext::Search::AbstractFactory->GetIndexers(
        $page->hub->current_workspace->name,
    );

    my $wksp_id = $page->hub->current_workspace->workspace_id;
    my $page_id = $page->id;
    for my $indexer (@indexers) {
        my $solr = ref($indexer) =~ m/solr/i;
        next if $solr; # XXX - turn OFF Solr indexing for page content.

        my $job_id = $self->insert(
            'Socialtext::Job::PageIndex' => {
                workspace_id => $wksp_id,
                page_id => $page_id,
                ($solr ? (solr => 1) : (search_config => $search_config)),
                job => {
                    priority => $opts{priority} || 63,
                    coalesce => (($solr ? 'solr' : 'kino') . "-$wksp_id-$page_id")
                },
            }
        );
        push @job_ids, $job_id;
    }

    my $attachments = $page->hub->attachments->all( page_id => $page->id );
    foreach my $attachment (@$attachments) {
        next if $attachment->deleted();
        for my $indexer (@indexers) {
            my $job_id;
            if (ref($indexer) =~ m/solr/i) {
                next; # XXX - turn OFF Solr indexing for attachment content.
                $job_id = $self->index_attachment($attachment, 'solr');
            }
            else {
                $job_id = $self->index_attachment($attachment, $search_config);
            }
            push @job_ids, $job_id;
        }
    }

    return @job_ids;
}

sub send_page_email {
    my $self = shift;
    my %opts = @_;

    return $self->insert( "Socialtext::Job::EmailPage" => \%opts );
}

sub send_page_notifications {
    my $self = shift;
    my $page = shift;

    my @tasks = (qw/WeblogPing EmailNotify WatchlistNotify/);
    return $self->_send_page_notifications($page, \@tasks);
}

sub send_page_watchlist_emails {
    my $self = shift;
    my $page = shift;

    return $self->_send_page_notifications($page, ['EmailNotify']);
}

sub send_page_email_notifications {
    my $self = shift;
    my $page = shift;

    return $self->_send_page_notifications($page, ['WatchlistNotify']);
}

sub _send_page_notifications {
    my $self = shift;
    my $page = shift;
    my $notification_tasks = shift; # array reference of notification tasks
    
    my $ws_id = $page->hub->current_workspace->workspace_id;
    my $page_id = $page->id;

    my @job_ids;

    for my $task (@$notification_tasks) {
        push @job_ids, $self->insert(
            "Socialtext::Job::$task" => {
                workspace_id => $ws_id,
                page_id => $page_id,
                modified_time => $page->modified_time,
                job => { uniqkey => "$ws_id-$page_id" },
            }
        );
    }
    return @job_ids;
}

sub index_signal {
    my $self = shift;
    my $signal_or_id = shift;
    my %p = @_;
    $p{priority} ||= 70;

    # accept either a signal object or a signal id.
    my $id = (ref($signal_or_id) && $signal_or_id->isa('Socialtext::Signal'))
        ? $signal_or_id->signal_id
        : $signal_or_id;

    my $job_id = $self->insert(
        'Socialtext::Job::SignalIndex' => {
            solr => 1,
            signal_id => $id,
            job => {
                priority => $p{priority},
                coalesce => $id,
            },
        }
    );
    return ($job_id);
}

sub index_group {
    my $self = shift;
    my $group_or_id = shift;
    my %p = @_;
    $p{priority} ||= 70;

    # accept either a group object or a group id.
    my $id = (ref($group_or_id) && $group_or_id->isa('Socialtext::Group'))
        ? $group_or_id->group_id
        : $group_or_id;

    my $job_id = $self->insert(
        'Socialtext::Job::GroupIndex' => {
            solr => 1,
            group_id => $id,
            job => {
                priority => $p{priority},
                coalesce => $id,
            },
        }
    );
    return ($job_id);
}

sub index_person {
    my $self = shift;
    my $maybe_user = shift;
    my %p = @_;
    $p{priority} ||= 70;

    my $user_id = ref($maybe_user) ? $maybe_user->user_id : $maybe_user;

    my $job_id;
    unless ($self->_cache('personindex')->get($user_id)) {
        $job_id = $self->insert(
            'Socialtext::Job::PersonIndex' => {
                solr => 1,
                user_id => $user_id,
                job => {
                    priority => $p{priority},
                    coalesce => $user_id,
                    ($p{run_after} ? (run_after => $p{run_after}) : ()),
                },
            }
        );
        $self->_cache('personindex')->set($user_id,1);
    }

    if ($p{name_is_changing}) {
        eval { $self->_index_related_people($maybe_user, $user_id, %p); };
        warn $@ if $@;
        eval { $self->_index_related_groups($user_id); };
        warn $@ if $@;
    }
    return ($job_id);
}

sub _index_related_groups {
    my ($self, $user_id) = @_;

    my $sth = sql_execute(q{
        SELECT group_id FROM groups WHERE created_by_user_id = ?
        }, $user_id);
    while (my $row = $sth->fetchrow_arrayref) {
        $self->index_group($row->[0]);
    }
}

sub _index_related_people {
    my ($self, $maybe_user, $user_id, %p) = @_;
    local $@; # don't propagate
    my %to_reindex;
    require Socialtext::People::Profile;
    my $prof = Socialtext::People::Profile->GetProfile($maybe_user);
    my @attr_names = $prof->fields->relationship_names();
    for my $attr (@attr_names) {
        my $user_id = $prof->get_reln_id($attr);
        $to_reindex{$user_id} = 1 if $user_id;
    }
    for my $other_user_id (keys %to_reindex) {
        next if $self->_cache('personindex')->get($other_user_id);
        eval {
            $self->insert(
                'Socialtext::Job::PersonIndex' => {
                    solr => 1,
                    user_id => $other_user_id,
                    job => {
                        priority => $p{priority},
                        coalesce => $other_user_id,
                        ($p{run_after} ? (run_after => $p{run_after}) : ()),
                    },
                }
            );
            $self->_cache('personindex')->set($other_user_id,1);
        };
    }
}

sub _cache {
    my $self = shift;
    my $kind = shift;
    return Socialtext::Cache->cache("jobcreator:$kind");
}

__PACKAGE__->meta->make_immutable;
1;
