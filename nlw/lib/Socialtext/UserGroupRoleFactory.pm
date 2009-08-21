package Socialtext::UserGroupRoleFactory;
# @COPYRIGHT@

use MooseX::Singleton;
use List::Util qw(first);
use Socialtext::Events;
use Socialtext::Log qw(st_log);
use Socialtext::Role;
use Socialtext::Timer;
use Socialtext::UserGroupRole;
use namespace::clean -except => 'meta';

with qw(
    Socialtext::Moose::ObjectFactory
    Socialtext::Moose::Does::UserSearch
    Socialtext::Moose::Does::GroupSearch
);

sub Builds_sql_for { 'Socialtext::UserGroupRole' }

sub SqlSortOrder { 'user_id, group_id' }

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
    my ($self, $ugr, $timer) = @_;
    $self->_record_log_entry('ASSIGN', $ugr, $timer);
}

sub RecordUpdateLogEntry {
    my ($self, $ugr, $timer) = @_;
    $self->_record_log_entry('CHANGE', $ugr, $timer);
}

sub RecordDeleteLogEntry {
    my ($self, $ugr, $timer) = @_;
    $self->_record_log_entry('REMOVE', $ugr, $timer);
}

# This form is deprecated in favour of 'Get()', but exists for backwards
# compatibility with previous implementation
sub GetUserGroupRole {
    return shift->Get(@_);
}

sub CreateRecord {
    my ($self, $proto_ugr) = @_;

    # Only concern ourselves with valid Db Columns
    my $valid = $self->FilterValidColumns( $proto_ugr );

    # SANITY CHECK: need all required attributes
    my $missing =
        first { not defined $valid->{$_} }
        map   { $_->name }
        grep  { $_->is_required }
        $self->Sql_columns;
    die "need a $missing attribute to create a UserGroupRole" if $missing;

    # INSERT the new record into the DB
    $self->SqlInsert( $valid );
    $self->EmitCreateEvent($valid);
}

sub Create {
    my ($self, $proto_ugr) = @_;
    my $timer = Socialtext::Timer->new();

    $proto_ugr->{role_id} ||= $self->DefaultRoleId();
    $self->CreateRecord($proto_ugr);

    my $ugr = $self->Get(%{$proto_ugr});
    $self->RecordCreateLogEntry($ugr, $timer);
    return $ugr;
}

sub UpdateRecord {
    my ($self, $proto_ugr) = @_;

    # Only concern ourselves with valid Db Columns
    my $valid = $self->FilterValidColumns( $proto_ugr );

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
    $self->EmitUpdateEvent($proto_ugr) if $did_update;
    return $did_update;
}

sub Update {
    my ($self, $user_group_role, $proto_ugr) = @_;
    my $timer = Socialtext::Timer->new();

    # update the record for this UGR in the DB
    my $primary_key = $user_group_role->primary_key();
    my $updates_ref = {
        %{$proto_ugr},
        %{$primary_key},
    };
    my $did_update = $self->UpdateRecord($updates_ref);

    if ($did_update) {
        # merge the updates back into the UGR object, skipping primary key
        # columns (which *aren't* updateable)
        my $to_merge = $self->FilterNonPrimaryKeyColumns($updates_ref);

        foreach my $attr (keys %{$to_merge}) {
            my $setter = "_$attr";
            $user_group_role->$setter( $to_merge->{$attr} );
        }

        $self->RecordUpdateLogEntry($user_group_role, $timer);
    }

    return $user_group_role;
}

sub DeleteRecord {
    my ($self, $proto_ugr) = @_;

    # Only concern ourselves with valid Db Columns
    my $where = $self->FilterValidColumns( $proto_ugr );

    # DELETE the record in the DB
    my $sth = $self->SqlDeleteOneRecord( $where );

    my $did_delete = $sth->rows();
    $self->EmitDeleteEvent($proto_ugr) if $did_delete;

    return $did_delete;
}

sub Delete {
    my ($self, $ugr) = @_;
    my $timer = Socialtext::Timer->new();
    my $did_delete = $self->DeleteRecord( $ugr->primary_key() );
    $self->RecordDeleteLogEntry($ugr, $timer) if $did_delete;
    return $did_delete;
}

sub _emit_event {
    my ($self, $proto_ugr, $action) = @_;

    # System managed groups are acted on by the System User.
    #
    # non-system managed groups are currently unscoped/unsupported.
    my $group = Socialtext::Group->GetGroup(group_id => $proto_ugr->{group_id});
    my $actor = $group->is_system_managed()
                ? Socialtext::User->SystemUser()
                : die "unable to determine event actor";

    # Record the event
    Socialtext::Events->Record( {
        event_class => 'group',
        action      => $action,
        actor       => $actor,
        context     => $proto_ugr,
    } );
}

sub _record_log_entry {
    my ($self, $action, $ugr, $timer) = @_;
    my $msg = "$action,GROUP_ROLE,"
        . 'role:' . $ugr->role->name . ','
        . 'user:' . $ugr->user->username
            . '(' . $ugr->user->user_id . '),'
        . 'group:' . $ugr->group->driver_group_name
            . '(' . $ugr->group->group_id . '),'
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

Socialtext::UserGroupRoleFactory - Factory for ST::UserGroupRole objects

=head1 SYNOPSIS

  use Socialtext::UserGroupRoleFactory;

  $factory = Socialtext::UserGroupRoleFactory->instance();

  # create a new UGR
  $ugr = $factory->Create( {
      user_id   => $user_id,
      group_id  => $group_id,
      role_id   => $role_id,
  } );

  # retrieve a UGR
  $ugr = $factory->Get(
      user_id  => $user_id,
      group_id => $group_id,
  );

  # update a UGR
  $factory->Update($ugr, \%updates_ref);

  # delete a UGR
  $factory->Delete($ugr);

=head1 DESCRIPTION

C<Socialtext::UserGroupRoleFactory> is used to manipulate the DB store for
C<Socialtext::UserGroupRole> objects.

=head1 METHODS

=over

=item B<$factory-E<gt>GetUserGroupRole(PARAMS)>

B<Deprecated.>  Use C<Get()> instead.

=item B<$factory-E<gt>Get(PARAMS)>

Looks for an existing record in the user_group_role table matching PARAMS and
returns a C<Socialtext::UserGroupRole> representing that row, or undef if it
can't find a match.

PARAMS I<must> contain:

=over

=item * user_id =E<gt> $user_id

=item * group_id =E<gt> $group_id

=back

=item B<$factory-E<gt>CreateRecord(\%proto_ugr)>

Create a new entry in the user_group_role table, if possible, and return the
corresponding C<Socialtext::UserGroupRole> object on success.

C<\%proto_ugr> I<must> include the following:

=over

=item * user_id =E<gt> $user_id

=item * group_id =E<gt> $group_id

=item * role_id =E<gt> $role_id

=back

=item B<$factory-E<gt>Create(\%proto_ugr)>

Create a new entry in the user_group_role table, a simplfied wrapper around
C<CreateRecord>.

C<\%proto_ugr> I<must> include the following:

=over

=item * user_id =E<gt> $user_id

=item * group_id =E<gt> $group_id

=back

It can I<optionally> include:

=over

=item * role_id =E<gt> $role_id

=back

If no C<$role_id> is provided, a default role will be used instead.  Refer to
C<DefaultRoleId()> for details.

=item B<$factory-E<gt>UpdateRecord(\%proto_ugr)>

Updates an existing user_group_role record in the DB, based on the information
provided in the C<\%proto_ugr> hash-ref.  Returns true if a record was updated
in the DB, returning false otherwise (e.g. if the update was effectively "no
change").

This C<\%proto_ugr> hash-ref B<MUST> contain the C<user_id> and C<group_id> of
the UGR that we are updating in the DB.

If you attempt to update a non-existing UGR, this method fails silently; no
exception is thrown, B<but> no data is updated/inserted in the DB (as it
didn't exist there in the first place).

=item B<$factory-E<gt>Update($ugr, \%proto_ugr)>

Updates the given C<$ugr> object with the information provided in the
C<\%proto_ugr> hash-ref.

Returns the updated C<$ugr> object back to the caller.

=item B<$factory-E<gt>DeleteRecord(\%proto_ugr)>

Deletes the user_group_role record from the DB, as described by the provided
C<\%proto_ugr> hash-ref.

Returns true if a record was deleted, false otherwise.

=item B<$factory-E<gt>Delete($ugr)>

Deletes the C<$ugr> from the DB.

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
