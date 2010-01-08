package Socialtext::Rest::Group::Workspaces;
# @COPYRIGHT@
use Moose;
extends 'Socialtext::Rest::Groups';
use Socialtext::Exceptions;
use Socialtext::Group;
use Socialtext::Permission qw/ST_READ_PERM/;
use namespace::clean -except => 'meta';

sub permission { +{} }
sub collection_name { 'Group Workspaces' }

sub _entity_hash { $_[1] }

sub _entities_for_query {
    my $self = shift;
    my $group_id = $self->group_id;
    my $user = $self->rest->user;

    my $group = Socialtext::Group->GetGroup(group_id => $group_id)
        or die Socialtext::Exception->NotFound->new();

    my $can_read = $group->user_can(
        user       => $user,
        permission => ST_READ_PERM,
    );
    die Socialtext::Exception::Auth->new()
       unless $user->is_business_admin
           || $group->creator->user_id == $user->user_id
           || $can_read;

    return sort { $a->title cmp $b->title }
       $group->workspaces->all();

}

sub _entity_hash {
    my $self      = shift;
    my $workspace = shift;

    return +{
        name          => $workspace->name,
        uri           => '/data/workspaces/' . $workspace->name,
        title         => $workspace->title,
        modified_time => $workspace->creation_datetime,
        id            => $workspace->workspace_id,
        default       => $workspace->is_default ? 1 : 0,
    };
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 NAME

Socialtext::Rest::Group::Workspaces - Resource handler for the Workspaces a
Group is a member of.

=head1 SYNOPSIS

    GET /data/groups/:group_id/workspaces

=head1 DESCRIPTION

View the details for a list of Workspaces that a Group is a member of.

=cut
