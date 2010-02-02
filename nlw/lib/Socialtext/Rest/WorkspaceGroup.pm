package Socialtext::Rest::WorkspaceGroup;
# @COPYRIGHT@

use Moose;
use Socialtext::HTTP ':codes';
use Socialtext::Group;
use Socialtext::Workspace;
use Socialtext::Permission qw(ST_ADMIN_PERM);
use Socialtext::Exceptions qw(conflict rethrow_exception);
use Socialtext::SQL qw(get_dbh :txn);
use Socialtext::JSON qw/decode_json/;
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest::Entity';

sub allowed_methods { 'DELETE' };

has 'target_group' => (
    is => 'ro', isa => 'Socialtext::Group', lazy_build => 1,
);

sub _build_target_group {
    my $self = shift;
    my $group_id = $self->group_id;
    my $group = Socialtext::Group->GetGroup(group_id => $group_id);
}

sub if_authorized {
    my $self = shift;
    my $call = shift;

    my $acting_user = $self->rest->user;
    my $checker = $self->hub->checker;

    return $self->no_workspace() unless $self->workspace;
    return $self->not_authorized() unless $self->can_admin;
    unless ($self->workspace->has_group($self->target_group)) {
        $self->rest->header( -status => HTTP_404_Not_Found );
        return $self->target_group->driver_group_name
             . " is not a member of "
             . $self->workspace->name;
    }
    return $self->$call(@_);
}

# Remove a Group from a Workspace
sub DELETE {
    my ($self, $rest) = @_;
    $self->if_authorized(sub {
        # Remove the Group from the WS
        $self->workspace->remove_group( group => $self->target_group );
        $rest->header( -status => HTTP_204_No_Content );
        return '';
    });
}

# Remove a Group from a Workspace
sub PUT {
    my ($self, $rest) = @_;
    $self->if_authorized(sub {
        my $content = $rest->getContent();

        my $dbh = get_dbh();
        my $in_txn = sql_in_transaction();
        $dbh->begin_work unless $in_txn;

        eval {
            my $object = decode_json( $content );
            die 'role parameter is required' unless $object->{role_name};

            my $role = Socialtext::Role->new(name => $object->{role_name});
            die "role '$object->{role_name}' doesn't exist" unless $role;

            $self->workspace->assign_role_to_group(
                group => $self->target_group, role => $role
            );

            my $admins = $self->workspace->role_count(
                role => Socialtext::Role->Admin(),
                direct => 1,
            );
            conflict errors => ["cannot delete last admin"] unless $admins;

            $dbh->commit unless $in_txn;
        };
        my $e = Exception::Class->caught('Socialtext::Exception::Conflict');
        if ($e) {
            $dbh->rollback unless $in_txn;
            return $self->conflict($e->errors);
        }
        elsif ( $@ )  {
            warn $@;
            $dbh->rollback unless $in_txn;
            $rest->header( -status => HTTP_400_Bad_Request );
            return $@;
        }
        
        $rest->header( -status => HTTP_204_No_Content );
        return '';
    });
}

sub can_admin {
    my $self = shift;

    return $self->rest->user->is_business_admin()
        || $self->rest->user->is_technical_admin()
        || $self->hub->checker->check_permission('admin_workspace')
        || $self->target_group->user_can(
            user => $self->rest->user,
            permission => ST_ADMIN_PERM,
        );
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
