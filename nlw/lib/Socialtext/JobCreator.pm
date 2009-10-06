package Socialtext::JobCreator;
# @COPYRIGHT@
use MooseX::Singleton;
use Socialtext::TheSchwartz;
use Socialtext::Search::AbstractFactory;
use Carp qw/croak/;
use Socialtext::Log qw/st_log/;
use namespace::clean -except => 'meta';

has '_client' => (
    is => 'ro', isa => 'Socialtext::TheSchwartz',
    lazy_build => 1,
    handles => qr/(?:list|find|get_server_time|func|move_jobs_by|cancel_job)/,
);

sub _build__client { Socialtext::TheSchwartz->new() }

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
        return $self->insert(
            'Socialtext::Job::AttachmentIndex' => {
                %job_args, solr => 1,
            }
        );
    }
    return $self->insert(
        'Socialtext::Job::AttachmentIndex' => {
            %job_args, search_config => $search_config,
        }
    );
}

sub index_page {
    my $self = shift;
    my $page = shift;
    my $search_config = shift;

    return if $page->is_bad_page_title($page->id);

    my @job_ids;

    my @indexers = Socialtext::Search::AbstractFactory->GetIndexers(
        $page->hub->current_workspace->name,
    );

    my $wksp_id = $page->hub->current_workspace->workspace_id;
    my $page_id = $page->id;
    for my $indexer (@indexers) {
        my $job_id = $self->insert(
            'Socialtext::Job::PageIndex' => {
                workspace_id => $wksp_id,
                page_id => $page_id,
                (ref($indexer) =~ m/solr/i ? (solr => 1)
                                           : (search_config => $search_config)),
                job => {
                    priority => 63,
                    coalesce => "$wksp_id-$page_id",
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
    my $signal = shift;
    my %p = @_;
    $p{priority} ||= 70;

    my $job_id = $self->insert(
        'Socialtext::Job::SignalIndex' => {
            solr => 1,
            signal_id => $signal->signal_id,
            job => {
                priority => $p{priority},
                coalesce => $signal->signal_id,
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

    my $job_id = $self->insert(
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
    return ($job_id);
}


__PACKAGE__->meta->make_immutable;
1;
