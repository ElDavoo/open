package Socialtext::GroupWorkspaceRoleFactory;
# @COPYRIGHT@

use MooseX::Singleton;
use Socialtext::Events;
use Socialtext::Log qw(st_log);
use Socialtext::Role;
use Socialtext::Pluggable::Adapter;
use Socialtext::SQL qw/:exec/;
use Socialtext::SQL::Builder qw/sql_abstract/;
use namespace::clean -except => 'meta';

with qw(
    Socialtext::CRUDFactory
    Socialtext::Moose::Does::GroupSearch
    Socialtext::Moose::Does::WorkspaceSearch
);

sub SortedResultSet {
    my $self = shift;
    my %opts = @_;

    my $from       = 'group_workspace_role gwr';
    my @where      = ();
    my @cols       = (
        'gwr.group_id AS group_id',
        'gwr.workspace_id AS workspace_id',
        'gwr.role_id'
    );

    my $order = ( $opts{order_by} && $opts{order_by} =~ /^\w+$/ )
        ? $opts{order_by}
        : 'group_id';


    @where = ( 'gwr.group_id' => $opts{group_id} ) if $opts{group_id};
    @where = ( 'gwr.workspace_id' => $opts{workspace_id} )
        if $opts{workspace_id};

    if ( $order eq 'name' ) {
        push @cols, '"Workspace".name AS name';
        $from .= qq{ JOIN "Workspace" USING (workspace_id) };
    }
    if ( $order eq 'user_count' ) {
        push @cols, 'user_aggregate.count AS user_count';
        $from .= q{
            LEFT JOIN (
                SELECT workspace_id,
                       COALESCE( COUNT(user_id), 0 ) AS count
                  FROM distinct_user_workspace_role
              GROUP BY workspace_id
            ) user_aggregate USING ( workspace_id )
        };
    }
    if ( $order eq 'account_name' ) {
        push @cols, '"Account".name AS account_name';
        $from .= q{ JOIN "Workspace" USING ( workspace_id )
                    JOIN "Account" USING ( account_id ) };
    }
    if ( $order eq 'creation_datetime' ) {
        push @cols, '"Workspace".creation_datetime AS creation_datetime';
        $from .= q{ JOIN "Workspace" USING ( workspace_id ) };
    }
    if ( $order eq 'creator' ) {
        push @cols, 'users.display_name AS creator';
        $from .= q{ JOIN "Workspace" USING ( workspace_id )
                    JOIN users ON
                         "Workspace".created_by_user_id = users.user_id };
    }

    $order .= ( $opts{sort_order} && ($opts{sort_order} =~ /^(a|de)sc$/) )
        ? " $opts{sort_order}"
        : ' ASC';

    $order .= ", " . $self->SqlSortOrder();

    my ($sql, @bind) = sql_abstract()->select(
        \$from, \@cols, \@where, $order, $opts{limit}, $opts{offset});

    my $sth = sql_execute($sql, @bind);
    return $self->Cursor($sth);
}

sub Builds_sql_for { 'Socialtext::GroupWorkspaceRole' }

sub SqlSortOrder { 'group_id, workspace_id' }

sub EmitCreateEvent {
    my ($self, $proto) = @_;
    $self->_emit_event($proto, 'create_role');
}

sub EmitUpdateEvent {
    my ($self, $proto) = @_;
    $self->_emit_event($proto, 'update_role');
}

sub EmitDeleteEvent {
    my ($self, $proto) = @_;
    $self->_emit_event($proto, 'delete_role');
}

sub RecordCreateLogEntry {
    my ($self, $gwr, $timer) = @_;
    $self->_record_log_entry('ASSIGN', $gwr, $timer);
}

sub RecordUpdateLogEntry {
    my ($self, $gwr, $timer) = @_;
    $self->_record_log_entry('CHANGE', $gwr, $timer);
}

sub RecordDeleteLogEntry {
    my ($self, $gwr, $timer) = @_;
    $self->_record_log_entry('REMOVE', $gwr, $timer);
}

sub SetDefaultValues {
    my ($self, $proto) = @_;
    $proto->{role_id} ||= $self->DefaultRoleId();
}

around 'Create' => sub {
    my $next = shift;
    my $gwr  = $next->(@_);

    # auto-create GAR for the Group and the WS's Primary Account
    my $adapter = Socialtext::Pluggable::Adapter->new;
    $adapter->make_hub(Socialtext::User->SystemUser());
    $adapter->hook( 'nlw.add_group_account_role',
        $gwr->workspace->account,
        $gwr->group,
        Socialtext::Role->Affiliate(),
    );

    return $gwr;
};

around 'Delete' => sub {
    my $next = shift;
    my ($self, $instance) = @_;
    my $did_delete = $next->($self, $instance);

    # auto-teardown GAR for the Group and the WS's Primary Account
    if ($did_delete) {
        my $adapter = Socialtext::Pluggable::Adapter->new;
        $adapter->make_hub(Socialtext::User->SystemUser());
        $adapter->hook( 'nlw.remove_group_account_role',
            $instance->workspace->account,
            $instance->group,
            Socialtext::Role->Affiliate(),
        );
    }
    return $did_delete;
};

sub DefaultRole {
    Socialtext::Role->Member();
}

sub DefaultRoleId {
    DefaultRole()->role_id();
}

sub _emit_event {
# No-op until we implement recording events for membership changes.
# Also: should $actor be the current_user from hub/rest?
# Also: refactor this and UGRF's _emit_event into a Moose::Role?
#     my ($self, $proto_gwr, $action) = @_;
# 
#     # System managed groups are acted on by the System User.
#     #
#     # non-system managed groups are currently unscoped/unsupported.
#     my $group = Socialtext::Group->GetGroup(group_id => $proto_gwr->{group_id});
#     my $actor = $group->is_system_managed()
#                 ? Socialtext::User->SystemUser()
#                 : die "unable to determine event actor";
# 
#     # Record the event
#     Socialtext::Events->Record( {
#         event_class => 'workspace',
#         action      => $action,
#         actor       => $actor,
#         context     => $proto_gwr,
#     } );
}

sub _record_log_entry {
    my ($self, $action, $gwr, $timer) = @_;
    my $msg = "$action,GROUP_WORKSPACE_ROLE,"
        . 'role:' . $gwr->role->name . ','
        . 'group:' . $gwr->group->driver_group_name
            . '(' . $gwr->group->group_id . '),'
        . 'workspace:' . $gwr->workspace->name
            . '(' . $gwr->workspace->workspace_id . '),'
        . '[' . $timer->elapsed . ']';
    st_log->info($msg);
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

Socialtext::GroupWorkspaceRoleFactory - Factory for ST::GroupWorkspaceRole objects

=head1 SYNOPSIS

  use Socialtext::GroupWorkspaceRoleFactory;

  $factory = Socialtext::GroupWorkspaceRoleFactory->instance();

  # create a new GWR
  $gwr = $factory->Create( {
      group_id     => $group_id,
      workspace_id => $workspace_id,
      role_id      => $role_id,
  } );

  # retrieve a GWR
  $gwr = $factory->Get(
      group_id     => $group_id,
      workspace_id => $workspace_id,
  );

  # update a GWR
  $factory->Update($gwr, \%updates_ref);

  # delete a GWR
  $factory->Delete($gwr);

=head1 DESCRIPTION

C<Socialtext::GroupWorkspaceRoleFactory> is used to manipulate the DB store
for C<Socialtext::GroupWorkspaceRole> objects.

=head1 METHODS

=over

=item B<$factory-E<gt>Get(PARAMS)>

Looks for an existing record in the group_workspace_role table matching PARAMS
and returns a C<Socialtext::GroupWorkspaceRole> representing that row, or
undef if it can't find a match.

PARAMS I<must> contain:

=over

=item * group_id =E<gt> $group_id

=item * workspace_id =E<gt> $workspace_id

=back

=item B<$factory-E<gt>CreateRecord(\%proto_gwr)>

Create a new entry in the group_workspace_role table, if possible, and return
the corresponding C<Socialtext::GroupWorkspaceRole> object on success.

C<\%proto_gwr> I<must> include the following:

=over

=item * group_id =E<gt> $group_id

=item * workspace_id =E<gt> $workspace_id

=item * role_id =E<gt> $role_id

=back

=item B<$factory-E<gt>Create(\%proto_gwr)>

Create a new entry in the group_workspace_role table, a simplfied wrapper
around C<CreateRecord>.

C<\%proto_gwr> I<must> include the following:

=over

=item * group_id =E<gt> $group_id

=item * workspace_id =E<gt> $workspace_id

=back

It can I<optionally> include:

=over

=item * role_id =E<gt> $role_id

=back

If no C<$role_id> is provided, a default role will be used instead.  Refer to
C<SetDefaultValues()> for details.

=item B<$factory-E<gt>SetDefaultValues(\%proto_gwr)>

Sets default values into the provided C<\%proto_gwr>, prior to creation of the
record in the DB.

If the C<\%proto_gwr> does not contain a C<role_id>, a default role will be
used instead.

=item B<$factory-E<gt>DefaultRole()>

Returns the C<Socialtext::Role> object for the default Role being used.

=item B<$factory-E<gt>DefaultRoleId()>

Get the ID for the default Role being used.

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
