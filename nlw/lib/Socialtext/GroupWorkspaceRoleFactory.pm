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

sub SetDefaultValues {
    my ($self, $proto) = @_;
    $proto->{role_id} ||= $self->DefaultRoleId();
}

sub DefaultRole {
    Socialtext::Role->Member();
}

sub DefaultRoleId {
    DefaultRole()->role_id();
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
