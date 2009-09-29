package Socialtext::Rest::Group;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Rest::Entity';
use Socialtext::HTTP ':codes';
use Socialtext::JSON;
use Socialtext::Group;

sub permission      { +{} }
sub allowed_methods {'GET'}
sub entity_name     { "Group" }

sub get_resource {
    my( $self, $rest ) = @_;

    my $group = Socialtext::Group->GetGroup(group_id => $self->group_id);
    return undef unless $group;

    my $user = $self->rest->user;
    if (   $user->is_business_admin or $group->has_user($user)
                                    or $group->creator->user_id == $user->user_id) {
        return $group->to_hash(
            show_members => $rest->query->param('show_members') ? 1 : 0,
        );
    }
    return undef;
}

1;
