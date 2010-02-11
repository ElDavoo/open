package Socialtext::Rest::WorkspaceRole;
# @COPYRIGHT@
use Moose::Role;
use Socialtext::Exceptions qw(conflict);
use Socialtext::HTTP ':codes';
use Socialtext::SQL ':txn';
use namespace::clean -except => 'meta';

sub modify_roles {
    my ($self, $call) = @_;

    my $in_txn = sql_in_transaction();
    sql_begin_work() unless $in_txn;

    eval {
        $call->();
        conflict
            errors => ["The workspace needs to include at least one admin."]
            unless $self->workspace->has_at_least_one_admin();
    };

    my $e = Exception::Class->caught('Socialtext::Exception::Conflict');
    if ($e) {
        sql_rollback() unless $in_txn;
        return $self->conflict($e->errors);
    }
    elsif ($@)  {
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

__END__

=head1 NAME

Socialtext::Rest::WorkspaceRole - Moose Role for workspace ReST contexts

=head1 SYNOPSIS

  use Moose;
  use Socialtext::Rest::Somethingerother;
  extends 'Socialtext::Rest';
  with 'Socialtext::Rest::WorkspaceRole';

=head1 DESCRIPTION

Helper methods for ReST endpoints that are in a workspace context (i.e.
contained in some URL-named workspace).

=head1 METHODS

=over 

=item modify_roles($callback)

Runs a callback in a transaction and IFF the operation resulted in this
workspace having no admin groups or users causes the transaction to rollback.

=item can_admin($callback)

Can the current rest user admin the active workspace? If so, call the
callback, otherwise call the C<not_authorized> method.

=back

=cut
