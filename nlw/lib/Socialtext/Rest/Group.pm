package Socialtext::Rest::Group;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Rest::Entity';
use Socialtext::HTTP ':codes';
use Socialtext::JSON;
use Socialtext::Permission qw(ST_READ_PERM);
use Socialtext::Group;

sub permission      { +{} }
sub allowed_methods {'GET'}
sub entity_name     { "Group" }

sub get_resource {
    my( $self, $rest ) = @_;

    my $group = Socialtext::Group->GetGroup(group_id => $self->group_id);
    return undef unless $group;

    my $can_read = $group->user_can(
        user => $self->rest->user,
        permission => ST_READ_PERM,
    );
    my $user = $self->rest->user;
    if ($user->is_business_admin or $can_read) {
        return $group->to_hash(
            show_members => $rest->query->param('show_members') ? 1 : 0,
            show_admins => $rest->query->param('show_admins') ? 1 : 0,
        );
    }
    return undef;
}

1;

=head1 NAME

Socialtext::Rest::Group - Group resource handler

=head1 SYNOPSIS

    GET /data/groups/:group_id

=head1 DESCRIPTION

View the details of a group.

=cut
