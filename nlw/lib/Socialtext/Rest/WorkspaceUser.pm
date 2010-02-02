package Socialtext::Rest::WorkspaceUser;
# @COPYRIGHT@
use Moose;
use Socialtext::HTTP ':codes';
use Socialtext::User;
use Socialtext::Workspace;
use Socialtext::JSON qw(decode_json);
use Socialtext::Exceptions qw(conflict rethrow_exception);
use Socialtext::SQL qw(get_dbh :txn);
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest::Entity';

sub allowed_methods {'DELETE, PUT'}

has 'target_user' => (
    is => 'ro', isa => 'Socialtext::User', lazy_build => 1,
);

sub _build_target_user {
    my $self = shift;
    return Socialtext::User->Resolve($self->username);
}

sub if_authorized {
    my $self = shift;
    my $call = shift;

    my $acting_user = $self->rest->user;
    my $checker = $self->hub->checker;

    return $self->no_workspace unless $self->workspace;
    return $self->not_authorized unless $self->can_admin;
    unless ($self->workspace->has_user($self->target_user) ) {
        $self->rest->header( -status => HTTP_404_Not_Found );
        return $self->username
            . " is not a member of "
            . $self->workspace->name;
    }
    return $self->$call(@_);
}

# Remove a user from a workspace
sub DELETE {
    my ( $self, $rest ) = @_;
    return $self->if_authorized(sub {
        # XXX: There's no gaurd against removing the last workspace admin.
        $self->workspace->remove_user( user => $self->target_user );
        $rest->header( -status => HTTP_204_No_Content );
        return '';
    });
}

# Remove a user from a workspace
sub PUT {
    my ( $self, $rest ) = @_;
    return $self->if_authorized(sub {
        my $content = $rest->getContent();

        my $dbh = get_dbh();
        my $in_txn = sql_in_transaction();
        $dbh->begin_work unless $in_txn;

        eval {
            my $object = decode_json( $content );
            die 'role parameter is required' unless $object->{role_name};

            my $role = Socialtext::Role->new(name => $object->{role_name});
            die "role '$object->{role_name}' doesn't exist" unless $role;

            $self->workspace->assign_role_to_user(
                user => $self->target_user, role => $role
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
        || $self->rest->user->user_id eq $self->target_user->user_id;
}


# SFP
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
