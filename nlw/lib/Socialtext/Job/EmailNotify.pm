package Socialtext::Job::EmailNotify;
# @COPYRIGHT@
use Moose;
use Socialtext::PreferencesPlugin;
use Socialtext::EmailNotifyPlugin;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

sub _should_run_on_page {
    my $self = shift;
    return $self->workspace->email_notify_is_enabled;
}

sub _user_job_class {
    return "Socialtext::Job::EmailNotifyUser";
}

sub _default_freq {
    return $Socialtext::EmailNotifyPlugin::Default_notify_frequency;
}

sub _pref_name {
    return 'notify_frequency';
}

sub _freq_for_user {
    my $self = shift;
    my $ws_id = shift;
    my $user_id = shift;

    my $pref_name = $self->_pref_name;
    my $pref_blob = Socialtext::PreferencesPlugin->Get_blob_matching(
        $ws_id, $user_id, qq{"$pref_name"},
    );
    my $freq = $self->_default_freq;
    if ($pref_blob and $pref_blob =~ m/"\Q$pref_name\E":"(\d+)"/) {
        $freq = $1;
    }
    return $freq * 60;
}
sub _get_applicable_user_ids {
    my $self = shift;
    return $self->workspace->user_ids;
}

sub do_work {
    my $self = shift;
    my $page = $self->page or return;
    my $ws = $self->workspace or return;
    my $hub = $self->hub;

    my $t = $self->arg->{modified_time};
    die "no modified_time supplied" unless defined $t;

    my $ws_id = $ws->workspace_id;

    return $self->completed unless $self->workspace->email_notify_is_enabled;

    return $self->completed if $page->is_system_page;
    local $Socialtext::Page::REFERENCE_TIME = $t;
    return $self->completed unless $page->is_recently_modified;

    $hub->log->info( "Sending recent changes notifications from ".$ws->name );
 
    my @jobs;
    my $user_ids = $self->_get_applicable_user_ids();
    my $job_class = $self->_user_job_class;
    for my $user_id (@$user_ids) {
        my $freq = $self->_freq_for_user($ws_id, $user_id);
        next unless $freq;

        my $after = $t + $freq;
        my $job = TheSchwartz::Moosified::Job->new(
            funcname => $job_class,
            priority => -64,
            run_after => $after,
            uniqkey => "$ws_id-$user_id",
            arg => {
                user_id => $user_id,
                workspace_id => $ws_id,
                pages_after => $t,
            }
        );
        push @jobs, $job if $job;
    }
    $hub->log->info("Creating " . scalar(@jobs) . " new $job_class jobs");

    $self->job->client->insert($_) for @jobs;
    $self->completed;
}

__PACKAGE__->meta->make_immutable;
1;
