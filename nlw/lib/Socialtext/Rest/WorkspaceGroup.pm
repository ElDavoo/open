package Socialtext::Rest::WorkspaceGroup;
# @COPYRIGHT@

use Moose;
use Socialtext::HTTP ':codes';
use Socialtext::Group;
use Socialtext::Workspace;
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest::Entity';

sub allowed_methods { 'DELETE' };

# Remove a Group from a Workspace
sub DELETE {
    my ($self, $rest) = @_;

    # Make sure we have a Workspace to work against.
    my $workspace = $self->workspace();
    return $self->no_workspace() unless $workspace;

    # Make sure we've got sufficient privs to do the DELETE
    unless ($self->_have_admin_privs()) {
        return $self->not_authorized();
    }

    # Get the Group
    my $group_id = $self->group_id();
    my $group = Socialtext::Group->GetGroup(group_id => $group_id);
    unless ($group) {
        $rest->header( -status => HTTP_404_Not_Found );
        return "Unable to find Group $group_id";
    }

    # Check if Group has _some_ Role in the WS
    unless ($workspace->has_group($group)) {
        $rest->header( -status => HTTP_404_Not_Found );
        return $group->driver_group_name
             . " is not a member of "
             . $workspace->name;
    }

    # Remove the Group from the WS
    $workspace->remove_group( group => $group );
    $rest->header( -status => HTTP_204_No_Content );
    return '';
}

sub _have_admin_privs {
    my $self = shift;
    return $self->rest->user->is_business_admin()
        || $self->rest->user->is_technical_admin()
        || $self->hub->checker->check_permission('admin_workspace');
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 NAME

Socialtext::Rest::WorkspaceGroups - Groups in a Workspace

=head1 SYNOPSIS

  DELETE /data/workspaces/:ws_name/groups/:group_id

=head1 DESCRIPTION

Every Socialtext Workspace has a collection of zero or more Groups associated
with it.  At the URIs above, it is possible to remove a Group from a
Workspace.

=cut
