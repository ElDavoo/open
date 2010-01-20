package Socialtext::Rest::UserWorkspaces;
# @COPYRIGHT@
use Moose;
extends 'Socialtext::Rest::Collection';
use Socialtext::User;
use Socialtext::Exceptions;
use Socialtext::Permission;
use namespace::clean -except => 'meta';

sub permission { +{} }
sub collection_name { 'User Workspaces' }

sub ensure_actor_can_view {
    my $self    = shift;
    my $subject = shift;
    my $actor   = $self->rest->user();

    die Socialtext::Exception::Auth->new()
        unless ($actor->is_business_admin ||
            $actor->user_id == $subject->user_id);
}

sub _entities_for_query {
    my $self    = shift;

    my $subject = eval { Socialtext::User->Resolve($self->username) };
    die Socialtext::Exception::NotFound->new() unless $subject;

    $self->ensure_actor_can_view($subject);

    my @workspaces = $subject->workspaces->all();

    my $perm_name = $self->rest->query->param('permission');
    if ($perm_name) {
        my $perm = Socialtext::Permission->new(name => $perm_name);
        die Socialtext::Exception::Params->new() unless $perm;

        @workspaces = grep {
            $_->permissions->user_can(
                user       => $subject,
                permission => $perm,
            )
        } @workspaces;
    }

    return @workspaces;
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
        workspace_id  => $workspace->workspace_id,
        default       => $workspace->is_default ? 1 : 0,
    };
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 NAME

Socialtext::Rest::UserWorkspaces

=head1 SYNOPSIS

    GET /data/users/:username/workspaces
    GET /data/users/:username/workspaces?permisison=read

=head1 DESCRIPTION

View the workspaces that a user has a role in.

=cut
