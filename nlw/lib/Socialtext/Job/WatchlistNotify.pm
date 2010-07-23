package Socialtext::Job::WatchlistNotify;
# @COPYRIGHT@
use Moose;
use Socialtext::Watchlist;
use Socialtext::WatchlistPlugin;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job::EmailNotify';

override '_user_job_class' => sub {
    return "Socialtext::Job::WatchlistNotifyUser";
};

override '_default_freq' => sub {
    return $Socialtext::WatchlistPlugin::Default_notify_frequency;
};

override '_pref_name' => sub {
    return 'watchlist_notify_frequency';
};


sub _get_applicable_user_ids {
    my $self = shift;

    # find the users that have this page watched.
    return Socialtext::Watchlist->Users_watching_page(
        $self->workspace->workspace_id, $self->page->id,
    );
}

__PACKAGE__->meta->make_immutable;
1;
