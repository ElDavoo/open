package Socialtext::Events::Stream::ProfileActivity;
use Moose;
use MooseX::AttributeHelpers;
use MooseX::StrictConstructor;
use namespace::clean -except => 'meta';

extends 'Socialtext::Events::Stream';

override 'add_sources' => sub {
    my $self = shift;
    my $sources = shift;

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
};

__PACKAGE__->meta->make_immutable;
1;
