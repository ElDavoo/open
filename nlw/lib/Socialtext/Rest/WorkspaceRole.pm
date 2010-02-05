package Socialtext::Rest::WorkspaceRole;
# @COPYRIGHT@
use Moose::Role;
use Socialtext::Exceptions qw(conflict);
use Socialtext::HTTP ':codes';
use Socialtext::SQL ':txn';
use namespace::clean -except => 'meta';

# This subroutine runs some operation in a transaction and rolls back and
# errors if the operation resulted in this workspace having no admin groups or
# users
sub modify_roles {
    my ($self, $call) = @_;

    my $in_txn = sql_in_transaction();
    sql_begin_work() unless $in_txn;

    eval {
        $call->();

        my $admins = $self->workspace->role_count(
            role => Socialtext::Role->Admin(),
            direct => 1,
        );
        conflict errors => ["You cannot remove the last admin"] unless $admins;
    };

    my $e = Exception::Class->caught('Socialtext::Exception::Conflict');
    if ($e) {
        sql_rollback() unless $in_txn;
        return $self->conflict($e->errors);
    }
    elsif ($@)  {
        warn $@;
        sql_rollback() unless $in_txn;
        $self->rest->header( -status => HTTP_400_Bad_Request );
        return $@;
    }

    sql_commit() unless $in_txn;
    $self->rest->header( -status => HTTP_204_No_Content );
    return '';
}


sub can_admin {
    my $self = shift;
    my $call = shift;

    my $actor = $self->rest->user;
    my $ws    = $self->workspace;

    return $self->no_workspace() unless $ws;

    my $has_auth = $actor->is_business_admin
        || $actor->is_technical_admin 
        || $self->hub->checker->check_permission('admin_workspace');

    return ($has_auth) ? $call->(@_) : $self->not_authorized();
}

1;
