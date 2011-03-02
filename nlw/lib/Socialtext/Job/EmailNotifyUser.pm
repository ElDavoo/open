package Socialtext::Job::EmailNotifyUser;
# @COPYRIGHT@
use Moose;
use Socialtext::EmailNotifier;
use Socialtext::URI;
use Socialtext::l10n qw/loc loc_lang system_locale/;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

override 'retry_delay' => sub { 0 };

override 'inflate_arg' => sub {
    my $self = shift;
    my $arg = $self->arg;
    return unless $arg;
    my ($user_id, $ws_id, $pages_after) = split '-', $arg;
    $self->arg({
        user_id      => $user_id,
        workspace_id => $ws_id,
        pages_after  => $pages_after,
    });
};

sub do_work {
    my $self = shift;

    my $user = $self->user or return;
    my $ws   = $self->workspace or return;
    my $hub  = $self->hub or return;

    return $self->completed
        unless $ws->real && $ws->email_notify_is_enabled;

    return $self->completed
        unless defined $user->email_address
            && length $user->email_address
            && !$user->requires_confirmation();

    return $self->completed unless $ws->has_user($user);

    loc_lang(system_locale());

    my $pages = $self->_pages_to_send;
    my $pages_fetched_at = time;
    return $self->completed unless $pages && @$pages;

    my $prefs = $hub->preferences->new_for_user($user);
    $pages = $self->_sort_pages_for_user($user, $pages, $prefs);

    my $tz = $hub->timezone;
    my $email_time = $tz->_now();
    my %vars = (
        user             => $user,
        workspace        => $ws,
        pages            => $pages,
        include_editor   => $self->_links_only($prefs),
        email_time       => $tz->get_time_user($email_time) ,
        email_date       => $tz->get_dateonly_user($email_time) ,
        base_profile_uri => Socialtext::URI::uri(path => 'st/profile/'),
        $self->_extra_template_vars(),
    );

    eval {
        my $notifier = Socialtext::EmailNotifier->new();
        $notifier->send_notifications(
            user  => $user,
            pages => $pages,
            vars  => \%vars,
            from  => $ws->formatted_email_notification_from_address,
            $self->_notification_vars,
        );
    };
    $self->hub->log->error($@) if $@;

    my @clone_args = map { $_ => $self->job->$_ }
        qw(funcid funcname priority uniqkey coalesce);

    my $next_interval_job = TheSchwartz::Moosified::Job->new({
        @clone_args,
        run_after => $pages_fetched_at + $self->_frequency_pref($prefs),
        arg => {
            %{$self->arg},
            pages_after => $pages_fetched_at,
        }
    });

    $self->job->replace_with($next_interval_job);
}

{
    my %SortSubs = (
        chrono  => sub { $b->age_in_seconds <=> $a->age_in_seconds },
        reverse => sub { $a->age_in_seconds <=> $b->age_in_seconds },
        default => sub { $a->id cmp $b->id },
    );

    sub _sort_pages_for_user {
        my $self  = shift;
        my $user  = shift;
        my $pages = shift;
        my $prefs = shift;

        my $sort_order = $prefs->sort_order->value;
        my $sort_sub =
              $sort_order && $SortSubs{$sort_order}
            ? $SortSubs{$sort_order}
            : $SortSubs{default};

        return [ sort $sort_sub @$pages ];
    }
}

sub _notification_vars {
    my $self = shift;
    my $ws = $self->workspace;

    return (
        subject => loc('email.recent-changes=wiki', $ws->title),
        text_template => 'email/recent-changes.txt',
        html_template => 'email/recent-changes.html',
    );
}

sub _pages_to_send {
    my $self = shift;
    return [
        grep { !$_->is_system_page }
            $self->hub->pages->all_at_or_after($self->arg->{pages_after})
    ];
}

sub _extra_template_vars {
    my $self = shift;
    return (
        preference_uri   => $self->workspace->uri . 'emailprefs',
    );
}

sub _links_only {
    my $self = shift;
    my $prefs = shift;
    return $prefs->links_only->value eq 'condensed' ? 0 : 1;
}

sub _frequency_pref {
    my $self = shift;
    my $prefs = shift;
    return $prefs->{notify_frequency}->value * 60;
}


__PACKAGE__->meta->make_immutable(inline_constructor => 1);
1;
