package Socialtext::Rest::Events::Groups;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Rest::EventsBase';
use Socialtext::Exceptions;

use Socialtext::l10n 'loc';

sub collection_name { 
    my $self = shift;
    return loc("[_1]'s Activity", $self->_group->display_name);
}

sub get_resource {
    my ($self, $rest) = @_;
    my $viewer = $self->rest->user;

    my $events = Socialtext::Events->GetGroupActivities(
        $viewer, $self->_group, $self->extract_common_args(),
    );
    $events ||= [];
    return $events;
}

sub _group {
    my $self = shift;
    my $group_id = $self->group_id;
    my $viewer = $self->rest->user;

    my $group = Socialtext::Group->GetGroup(group_id => $group_id);
    if ($group) {
        return $group if $viewer->is_business_admin;
        return $group if $group->has_user($viewer);
        Socialtext::Exception::Auth->throw();
    }

    Socialtext::Exception::NoSuchResource->throw(name => "group: $group_id")
}

1;

=head1 NAME

Socialtext::Rest::Events::Groups - Activity stream for a group.

=head1 SYNOPSIS

    GET /data/events/groups/:group_id

=head1 DESCRIPTION

View the activity stream for the group.

=cut
