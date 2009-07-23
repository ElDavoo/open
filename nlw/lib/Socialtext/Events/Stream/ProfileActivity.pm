package Socialtext::Events::Stream::ProfileActivity;
# @COPYRIGHT@
use Moose;
use namespace::clean -except => 'meta';

extends 'Socialtext::Events::Stream';

override '_build_sources' => sub {
    my $self = shift;
    my $sources = [];

    {
        my $fp = $self->filter->clone;
        $fp->contributions(1);
        $fp->actor_id($self->user_id);
        push @$sources, $self->construct_source(
            'Socialtext::Events::Stream' => (
                traits => ['HasPages'],
                filter => $fp,
            ));
    }

    if ($self->viewer->can_use_plugin_with('people' => $self->user)) {
        my $accts = $self->account_ids_for_plugin('people');
        push @$sources, $self->construct_source(
            'Socialtext::Events::Source::PersonVisible' => (
                visible_account_ids => $accts,
                activity_mode => 1,
            )
        );
    }

    if ($self->viewer->can_use_plugin_with('signals' => $self->user)) {
        my $accts = $self->account_ids_for_plugin('signals');

        # direct between user and viewer
        push @$sources, $self->construct_source(
            'Socialtext::Events::Source::SignalPersonal'
        );

        # sent to a shared account by the user
        # any signal mentioning that user (to a shared account)
        push @$sources, $self->construct_source(
            'Socialtext::Events::Source::Signals' => (
                viewer => $self->viewer,
                user => $self->user,
                account_ids => $accts,
                activity_mode => 1, # includes mentions
            )
        );
    }

    return $sources;
};

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

Socialtext::Events::Stream::ProfileActivity - The "Activity" feed on a
person's profile page.

=head1 DESCRIPTION

Composes a number of Streams where the events have a relationship with the
"owner" of this stream (the C<user> paramater).  Event visibility should be
limited to events that the C<viewer> can see.  Direct/private events (e.g.
signals) between the C<user> and C<viewer> are included.

This stream is heterogenous; Page, Person, and Signal events are mixed
together in this stream.

Cannot be composed with other Stream roles.

=head1 SYNOPSIS

    my $c = Socialtext::Events::Stream::ProfileActivity->new(
        viewer => $viewer_user,
        user => $owner_user,
        limit => 50,
        offset => 0,
        filter => Socialtext::Events::FilterParams->new(
            after => 'a week ago', # not literally; use a iso8601 string
        ),
    );

