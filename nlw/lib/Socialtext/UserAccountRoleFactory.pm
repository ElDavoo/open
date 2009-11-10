package Socialtext::UserAccountRoleFactory;
# @COPYRIGHT@

use MooseX::Singleton;
use Socialtext::Events;
use Socialtext::Log qw(st_log);
use Socialtext::Role;
use namespace::clean -except => 'meta';

with qw(
    Socialtext::CRUDFactory
    Socialtext::Moose::Does::UserSearch
    Socialtext::Moose::Does::AccountSearch
);

sub Builds_sql_for { 'Socialtext::UserAccountRole' }

sub SqlSortOrder { 'user_id, account_id' }

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
    my ($self, $uar, $timer) = @_;
    $self->_record_log_entry('ASSIGN', $uar, $timer);
}

sub RecordUpdateLogEntry {
    my ($self, $uar, $timer) = @_;
    $self->_record_log_entry('CHANGE', $uar, $timer);
}

sub RecordDeleteLogEntry {
    my ($self, $uar, $timer) = @_;
    $self->_record_log_entry('REMOVE', $uar, $timer);
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
    my ($self, $proto_uar, $action) = @_;
    my $actor = Socialtext::User->SystemUser();
    # Record the event
#     Socialtext::Events->Record( {
#         event_class => 'account',
#         action      => $action,
#         actor       => $actor,
#         context     => $proto_uar,
#     } );
}

sub _record_log_entry {
    my ($self, $action, $uar, $timer) = @_;
    my $msg = "$action,ACCOUNT_ROLE,"
        . 'role:' . $uar->role->name . ','
        . 'user:' . $uar->user->username
            . '(' . $uar->user->user_id . '),'
        . 'account:' . $uar->account->name
            . '(' . $uar->account->account_id . '),'
        . '[' . $timer->elapsed . ']';
    st_log->info($msg);
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

Socialtext::UserAccountRoleFactory - Factory for ST::UserAccountRole objects

=head1 SYNOPSIS

  use Socialtext::UserAccountRoleFactory;

  $factory = Socialtext::UserAccountRoleFactory->instance();

  # create a new UAR
  $uar = $factory->Create( {
      user_id    => $user_id,
      account_id => $account_id,
      role_id    => $role_id,
  } );

  # retrieve a UAR
  $uar = $factory->Get(
      user_id    => $user_id,
      account_id => $account_id,
  );

  # update a UAR
  $factory->Update($uar, \%updates_ref);

  # delete a UAR
  $factory->Delete($uar);

=head1 DESCRIPTION

C<Socialtext::UserAccountRoleFactory> is used to manipulate the DB store for
C<Socialtext::UserAccountRole> objects.

=head1 METHODS

=over

=item B<$factory-E<gt>Get(PARAMS)>

Looks for an existing record in the user_account_role table matching PARAMS and
returns a C<Socialtext::UserAccountRole> representing that row, or undef if it
can't find a match.

PARAMS I<must> contain:

=over

=item * user_id =E<gt> $user_id

=item * account_id =E<gt> $account_id

=back

=item B<$factory-E<gt>CreateRecord(\%proto_uar)>

Create a new entry in the user_account_role table, if possible, and return the
corresponding C<Socialtext::UserAccountRole> object on success.

C<\%proto_uar> I<must> include the following:

=over

=item * user_id =E<gt> $user_id

=item * account_id =E<gt> $account_id

=item * role_id =E<gt> $role_id

=back

=item B<$factory-E<gt>Create(\%proto_uar)>

Create a new entry in the user_account_role table, a simplfied wrapper around
C<CreateRecord>.

C<\%proto_uar> I<must> include the following:

=over

=item * user_id =E<gt> $user_id

=item * account_id =E<gt> $account_id

=back

It can I<optionally> include:

=over

=item * role_id =E<gt> $role_id

=back

If no C<$role_id> is provided, a default role will be used instead.  Refer to
C<SetDefaultValues()> for details.

=item B<$factory-E<gt>SetDefaultValues(\%proto_uar)>

Sets default values into the provided C<\%proto_uar>, prior to creation of the
record in the DB.

If the C<\%proto_uar> does not contain a C<role_id>, a default role will be
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
