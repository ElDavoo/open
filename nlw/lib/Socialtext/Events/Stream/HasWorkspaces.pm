package Socialtext::Events::Stream::HasWorkspaces;
use Moose::Role;
use Socialtext::SQL qw/:exec/;
use Socialtext::SQL::Builder qw/sql_abstract/;
use List::Util qw/first/;
use namespace::clean -except => 'meta';

requires 'assemble';

has 'workspace_ids' => (
    is => 'rw', isa => 'ArrayRef[Int]',
    lazy_build => 1,
);

before 'assemble' => sub {
    my $self = shift;
    $self->workspace_ids; # force builder
    return;
};

sub _build_workspace_ids {
    my $self = shift;

    my $acct_filter = $self->filter->has_account_id;
    if ($acct_filter && !$self->filter->account_id) {
        $self->filter->clear_account_id;
        undef $acct_filter;
    }

    # TODO: respect group membership
    my ($member_sql, @member_bind);
    {
        my $from = q{"UserWorkspaceRole"};
        my @where = (user_id => $self->viewer_id);

        if ($acct_filter) {
            $from .= ' JOIN "Workspace" USING (workspace_id)';
            push @where, account_id => $self->filter->account_id;
        }

        ($member_sql, @member_bind) = sql_abstract()->select(
            \$from, 'workspace_id', {-and => \@where}
        );
    }

    my ($guest_sql, @guest_bind);
    {
        my $from = q{
            "WorkspaceRolePermission" wrp
            JOIN "Role" r USING (role_id)
            JOIN "Permission" p USING (permission_id)
        };
        my @where = (\[q{r.name = 'guest' AND p.name = 'read'}]);

        if ($acct_filter) {
            $from .= ' JOIN "Workspace" USING (workspace_id)';
            push @where, account_id => $self->filter->account_id;
        }

        ($guest_sql, @guest_bind) = sql_abstract()->select(
            \$from, 'workspace_id', {-and => \@where}
        );
    }

    local $Socialtext::SQL::TRACE_SQL = 1;
    my $sth = sql_execute(
        "$member_sql \n UNION \n $guest_sql",
        @member_bind, @guest_bind
    );
    my $rows = $sth->fetchall_arrayref;

    if ($self->filter->has_page_workspace_id) {
        my $wses = $self->filter->page_workspace_id;
        if (!defined $wses) {
            # just use visible workspaces
        }
        elsif (ref($wses)) {
            my %wanted = map { $_ => 1 } @$wses;
            @$rows = grep { $wanted{$_->[0]} } @$rows;
        }
        else {
            @$rows = first {$wses==$_->[0]} @$rows;
        }
    }

    return [grep {defined} map { $_->[0] } @$rows];
}

1;
