package Socialtext::GroupWorkspaceRoleFactory;
# @COPYRIGHT@

use MooseX::Singleton;
use List::Util qw(first);
use Socialtext::Events;
use Socialtext::Log qw(st_log);
use Socialtext::Role;
use Socialtext::Timer;
use Socialtext::GroupWorkspaceRole;
use namespace::clean -except => 'meta';

with qw(
    Socialtext::Moose::ObjectFactory
    Socialtext::Moose::Does::GroupSearch
    Socialtext::Moose::Does::WorkspaceSearch
);

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

# This form is deprecated in favour of 'Get()', but exists for backwards
# compatibility with previous implementation
sub GetGroupWorkspaceRole {
    return shift->Get(@_);
}

sub CreateRecord {
    my ($self, $proto_gwr) = @_;

    # Only concern ourselves with valid Db Columns
    my $valid = $self->FilterValidColumns( $proto_gwr );

    # SANITY CHECK: need all required attributes
    my $missing =
        first { not defined $valid->{$_} }
        map   { $_->name }
        grep  { $_->is_required }
        $self->Sql_columns;
    die "need a $missing attribute to create a GroupWorkspaceRole" if $missing;

    # INSERT the new record into the DB
    $self->SqlInsert( $valid );
    $self->EmitCreateEvent($valid);
}

sub Create {
    my ($self, $proto_gwr) = @_;
    my $timer = Socialtext::Timer->new();

    $proto_gwr->{role_id} ||= $self->DefaultRoleId();
    $self->CreateRecord($proto_gwr);

    my $gwr = $self->GetGroupWorkspaceRole(%{$proto_gwr});
    $self->RecordCreateLogEntry($gwr, $timer);
    return $gwr;
}

sub UpdateRecord {
    my ($self, $proto_gwr) = @_;

    # Only concern ourselves with valid Db Columns
    my $valid = $self->FilterValidColumns( $proto_gwr );

    # Update is done against the primary key
    my $pkey = $self->FilterPrimaryKeyColumns( $valid );

    # Don't allow for primary key fields to be updated
    my $values = $self->FilterNonPrimaryKeyColumns( $valid );

    # If there's nothing to update, *don't*.
    return unless %{$values};

    # UPDATE the record in the DB
    my $sth = $self->SqlUpdateOneRecord( {
        values => $values,
        where  => $pkey,
    } );

    my $did_update = ($sth && $sth->rows) ? 1 : 0;
    $self->EmitUpdateEvent($proto_gwr) if $did_update;
    return $did_update;
}

sub Update {
    my ($self, $group_workspace_role, $proto_gwr) = @_;
    my $timer = Socialtext::Timer->new();

    # update the record for this GWR in the DB
    my $primary_key = $group_workspace_role->primary_key();
    my $updates_ref = {
        %{$proto_gwr},
        %{$primary_key},
    };
    my $did_update = $self->UpdateRecord($updates_ref);

    if ($did_update) {
        # merge the updates back into the GWR object, skipping primary key
        # columns (which *aren't* updateable
        my $to_merge = $self->FilterNonPrimaryKeyColumns($updates_ref);

        foreach my $attr (keys %{$to_merge}) {
            my $setter = "_$attr";
            $group_workspace_role->$setter( $updates_ref->{$attr} );
        }

        $self->RecordUpdateLogEntry($group_workspace_role, $timer);
    }

    return $group_workspace_role;
}

sub DeleteRecord {
    my ($self, $proto_gwr) = @_;

    # Only concern ourselves with valid Db Columns
    my $where = $self->FilterValidColumns( $proto_gwr );

    # DELETE the record in the DB
    my $sth = $self->SqlDeleteOneRecord( $where );

    my $did_delete = $sth->rows();
    $self->EmitDeleteEvent($proto_gwr) if $did_delete;

    return $did_delete;
}

sub Delete {
    my ($self, $gwr) = @_;
    my $timer = Socialtext::Timer->new();
    my $did_delete = $self->DeleteRecord( $gwr->primary_key() );
    $self->RecordDeleteLogEntry($gwr, $timer) if $did_delete;
    return $did_delete;
}

sub _emit_event {
    my ($self, $proto_gwr, $action) = @_;

    # System managed groups are acted on by the System User.
    #
    # non-system managed groups are currently unscoped/unsupported.
    my $group = Socialtext::Group->GetGroup(group_id => $proto_gwr->{group_id});
    my $actor = $group->is_system_managed()
                ? Socialtext::User->SystemUser()
                : die "unable to determine event actor";

    # Record the event
    Socialtext::Events->Record( {
        event_class => 'workspace',
        action      => $action,
        actor       => $actor,
        context     => $proto_gwr,
    } );
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

sub DefaultRole {
    Socialtext::Role->Member();
}

sub DefaultRoleId {
    DefaultRole()->role_id();
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
  $gwr = $factory->GetGroupWorkspaceRole(
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

=item B<$factory-E<gt>GetGroupWorkspaceRole(PARAMS)>

B<Deprecated.>  Use C<Get()> instead.

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
C<DefaultRoleId()> for details.

=item B<$factory-E<gt>UpdateRecord(\%proto_gwr)>

Updates an existing group_workspace_role record in the DB, based on the
information provided in the C<\%proto_gwr> hash-ref.  Returns true if a record
was updated in the DB, returning false otherwise (e.g. if the update was
effectively "no change").

This C<\%proto_gwr> hash-ref B<MUST> contain the C<group_id> and
C<workspace_id> of the GWR that we are updating in the DB.

If you attempt to update a non-existing GWR, this method fails silently; no
exception is thrown, B<but> no data is updated/inserted in the DB (as it
didn't exist there in the first place).

=item B<$factory-E<gt>Update($gwr, \%proto_gwr)>

Updates the given C<$gwr> object with the information provided in the
C<\%proto_gwr> hash-ref.

Returns the updated C<$gwr> object back to the caller.

=item B<$factory-E<gt>DeleteRecord(\%proto_gwr)>

Deletes the group_workspace_role record from the DB, as described by the
provided C<\%proto_gwr> hash-ref.

Returns true if a record was deleted, false otherwise.

=item B<$factory-E<gt>Delete($gwr)>

Deletes the C<$gwr> from the DB.

Helper method which calls C<DeleteRecord()>.

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
