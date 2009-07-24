package Socialtext::Rest::Events::Conversations;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Rest::EventsBase';

use Socialtext::l10n 'loc';

sub collection_name { loc("My Conversations") }

sub get_resource {
    my ($self, $rest) = @_;
    my $viewer = $self->rest->user;
    my $user = eval { Socialtext::User->Resolve($self->user) };

    if (!$viewer || !$user || $viewer->user_id != $user->user_id) {
        die Socialtext::Exception::Auth->new(
            "A user can only view their own conversations");
    }

    my %args = $self->extract_common_args();
    my $reporter = Socialtext::Events::Reporter->new(viewer => $user);
    return $reporter->get_events_conversations($user, \%args);
}

1;
