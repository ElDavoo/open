package Socialtext::GroupAccountRoleFactory;
# @COPYRIGHT@

use MooseX::Singleton;
use Socialtext::Events;
use Socialtext::Log qw(st_log);
use Socialtext::Role;
use namespace::clean -except => 'meta';

with qw(
    Socialtext::Moose::ObjectFactory
    Socialtext::Moose::Does::GroupSearch
    Socialtext::Moose::Does::AccountSearch
);

sub Builds_sql_for { 'Socialtext::GroupAccountRole' }

sub SqlSortOrder { 'group_id, account_id' }

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
    my ($self, $gar, $timer) = @_;
    $self->_record_log_entry('ASSIGN', $gar, $timer);
}

sub RecordUpdateLogEntry {
    my ($self, $gar, $timer) = @_;
    $self->_record_log_entry('CHANGE', $gar, $timer);
}

sub RecordDeleteLogEntry {
    my ($self, $gar, $timer) = @_;
    $self->_record_log_entry('REMOVE', $gar, $timer);
}

sub SetDefaultValues {
    my ($self, $proto) = @_;
    $proto->{role_id} ||= $self->DefaultRoleId();
}

sub DefaultRole {
    Socialtext::Role->Affiliate();
}

sub DefaultRoleId {
    DefaultRole()->role_id();
}

sub _emit_event {
    my ($self, $proto_gar, $action) = @_;
    my $actor = Socialtext::User->SystemUser();

    # Record the event
    Socialtext::Events->Record( {
        event_class => 'account',
        action      => $action,
        actor       => $actor,
        context     => $proto_gar,
    } );
}

sub _record_log_entry {
    my ($self, $action, $gar, $timer) = @_;
    my $msg = "$action,GROUP_ACCOUNT_ROLE,"
        . 'role:' . $gar->role->name . ','
        . 'group:' . $gar->group->driver_group_name
            . '(' . $gar->group->group_id . '),'
        . 'account:' . $gar->account->name
            . '(' . $gar->account->account_id . '),'
        . '[' . $timer->elapsed . ']';
    st_log->info($msg);
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

Socialtext::GroupAccountRoleFactory - Factory for ST::GroupAccountRole objects

=head1 SYNOPSIS

  use Socialtext::GroupAccountRoleFactory;

  $factory = Socialtext::GroupAccountRoleFactory->instance();

  # create a new GAR
  $gar = $factory->Create( {
      group_id     => $group_id,
      account_id => $account_id,
      role_id      => $role_id,
  } );

  # retrieve a GAR
  $gar = $factory->Get(
      group_id     => $group_id,
      account_id => $account_id,
  );

  # update a GAR
  $factory->Update($gar, \%updates_ref);

  # delete a GAR
  $factory->Delete($gar);

=head1 DESCRIPTION

C<Socialtext::GroupAccountRoleFactory> is used to manipulate the DB store
for C<Socialtext::GroupAccountRole> objects.

=head1 METHODS

=over

=item B<$factory-E<gt>Get(PARAMS)>

Looks for an existing record in the group_account_role table matching PARAMS
and returns a C<Socialtext::GroupAccountRole> representing that row, or
undef if it can't find a match.

PARAMS I<must> contain:

=over

=item * group_id =E<gt> $group_id

=item * account_id =E<gt> $account_id

=back

=item B<$factory-E<gt>CreateRecord(\%proto_gar)>

Create a new entry in the group_account_role table, if possible, and return
the corresponding C<Socialtext::GroupAccountRole> object on success.

C<\%proto_gar> I<must> include the following:

=over

=item * group_id =E<gt> $group_id

=item * account_id =E<gt> $account_id

=item * role_id =E<gt> $role_id

=back

=item B<$factory-E<gt>Create(\%proto_gar)>

Create a new entry in the group_account_role table, a simplfied wrapper
around C<CreateRecord>.

C<\%proto_gar> I<must> include the following:

=over

=item * group_id =E<gt> $group_id

=item * account_id =E<gt> $account_id

=back

It can I<optionally> include:

=over

=item * role_id =E<gt> $role_id

=back

If no C<$role_id> is provided, a default role will be used instead.  Refer to
C<SetDefaultValues()> for details.

=item B<$factory-E<gt>SetDefaultValues(\%proto_gar)>

Sets default values into the provided C<\%proto_gar>, prior to creation of the
record in the DB.

If the C<\%proto_gar> does not contain a C<role_id>, a default role will be
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
