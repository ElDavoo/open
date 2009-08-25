package Socialtext::JobCreator;
# @COPYRIGHT@
use MooseX::Singleton;
use Socialtext::TheSchwartz;
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

    my $wksp_id = $page->hub->current_workspace->workspace_id;
    my $page_id = $page->id;
    my $main_job_id = $self->insert(
        'Socialtext::Job::PageIndex' => {
            workspace_id => $wksp_id,
            page_id => $page_id,
            search_config => $search_config,
            job => {
                priority => 63,
                coalesce => "$wksp_id-$page_id",
            },
        }
    );
    my $solr_job_id = $self->insert(
        'Socialtext::Job::PageIndex' => {
            workspace_id => $wksp_id,
            page_id => $page_id,
            solr => 1,
            job => {
                priority => 63,
                coalesce => "$wksp_id-$page_id",
            },
        }
    );
    push @job_ids, $main_job_id, $solr_job_id;

    my $attachments = $page->hub->attachments->all( page_id => $page->id );
    foreach my $attachment (@$attachments) {
        next if $attachment->deleted();
        my $job_id = $self->index_attachment($attachment, $search_config);
        my $solr_job_id = $self->index_attachment($attachment, 'solr');
        push @job_ids, $job_id, $solr_job_id;
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


__PACKAGE__->meta->make_immutable;
1;
