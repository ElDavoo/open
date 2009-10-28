package Socialtext::Rest::Group::User;
# @COPYRIGHT@
use Moose;
use Socialtext::HTTP ':codes';
use Socialtext::Group;
use Socialtext::User;
use namespace::clean -except => 'meta';
extends 'Socialtext::Rest::Entity';

sub DELETE {
    my $self = shift;
    my $rest = shift;

    # Only a Business Admin has permission to do this right now.
    unless ($self->user_can('is_business_admin')) {
        $rest->header( -status => HTTP_401_Unauthorized );
        return '';
    }

    my $group = Socialtext::Group->GetGroup( group_id => $self->group_id );
    die Socialtext::Exception::NotFound->new() unless $group;

    my $user = Socialtext::User->new( username => $self->username );
    die Socialtext::Exception::NotFound->new() unless $user;

    # Group is not Socialtext sourced, we don't control its membership.
    unless ( $group->can_update_store ) {
        $rest->header( -status => HTTP_400_Bad_Request );
        return 'Group membership cannot be changed';
    }

    unless ( $group->has_user($user) ) {
        $rest->header( -status => HTTP_400_Bad_Request );
        return 'User does not have a role in the Group';
    }

    $group->remove_user( user => $user );
    $rest->header( -status => HTTP_204_No_Content);
    return '';
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 NAME

Socialtext::Rest::Group::User - User in a Group

=head1 SYNOPSIS

    DELETE /data/groups/:group_id/users/:username

=head1 DESCRIPTION

Delete a User from a Group

=cut
