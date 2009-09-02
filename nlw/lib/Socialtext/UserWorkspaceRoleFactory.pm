package Socialtext::UserWorkspaceRoleFactory;
# @COPYRIGHT@
use MooseX::Singleton;
use Socialtext::Log qw(st_log);
use namespace::clean -except => 'meta';

with qw/Socialtext::Moose::ObjectFactory/;

sub Builds_sql_for {'Socialtext::UserWorkspaceRole'}

sub EmitCreateEvent {
    # No Events are recorded for this action
}

sub EmitDeleteEvent {
    # No Events are recorded for this action
}

sub EmitUpdateEvent {
    # No Events are recorded for this action
}

sub RecordCreateLogEntry {
    my $self  = shift;
    my $uwr   = shift;
    my $timer = shift;

    $self->_write_log( $uwr, $timer, 'ASSIGN' );
}

sub RecordDeleteLogEntry {
    my $self  = shift;
    my $uwr   = shift;
    my $timer = shift;

    $self->_write_log( $uwr, $timer, 'REMOVE' );
}

sub RecordUpdateLogEntry {
    my $self  = shift;
    my $uwr   = shift;
    my $timer = shift;

    $self->_write_log( $uwr, $timer, 'CHANGE' );
}

sub SetDefaultValues {
    my $self  = shift;
    my $proto = shift;

    $proto->{is_selected} ||= 1;
}

sub _write_log {
    my $self   = shift;
    my $uwr    = shift;
    my $timer  = shift;
    my $action = shift;

    st_log()->info($action . ',USER_ROLE,'
        . 'role:' . $uwr->role->name . ','
        . 'user:' . $uwr->user->username
        . '(' . $uwr->user_id . '),'
        . 'workspace:' . $uwr->workspace->name
        . '(' . $uwr->workspace->workspace_id . '),'
        . '[' . $timer->elapsed . ']'
    );
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Socialtext::UserWorkspaceRoleFactory - Factory for ST::UserWorkspaceRole objects

=head1 SYNOPSIS

  use Socialtext::UserWorkspaceRoleFactory;

  $factory = Socialtext::UserWorkspaceRoleFactory->instance();

  # create a new UWR
  $uwr = $factory->Create( {
      user_id      => $user_id,
      workspace_id => $workspace_id,
      role_id      => $role_id,
      is_selected  => 1,
  } );

  # retrieve a UWR
  $uwr = $factory->Get(
      user_id    => $user_id,
      workspace_id => $workspace_id,
  );

  # update a UWR
  $factory->Update($uwr, \%updates_ref);

  # delete a UWR
  $factory->Delete($uwr);

=head1 DESCRIPTION

C<Socialtext::UserWorkspaceRoleFactory> is used to manipulate the DB store for
C<Socialtext::UserWorkspaceRole> objects.

=head1 METHODS

=over

=item B<$factory-E<gt>Get(PARAMS)>

Looks for an existing record in the user_workspace_role table matching PARAMS
and returns a C<Socialtext::UserWorkspaceRole> representing that row, or undef
if it can't find a match.

PARAMS I<must> contain:

=over

=item * user_id =E<gt> $user_id

=item * workspace_id =E<gt> $workspace_id

=back

=item B<$factory-E<gt>CreateRecord(\%proto_uwr)>

Create a new entry in the user_workspace_role table, if possible, and return
the corresponding C<Socialtext::UserWorkspaceRole> object on success.

C<\%proto_uwr> I<must> include the following:

=over

=item * user_id =E<gt> $user_id

=item * workspace_id =E<gt> $workspace_id

=item * role_id =E<gt> $role_id

=back

=item B<$factory-E<gt>Create(\%proto_uwr)>

Create a new entry in the user_workspace_role table, a simplfied wrapper
around C<CreateRecord>.

C<\%proto_uwr> I<must> include the following:

=over

=item * user_id =E<gt> $user_id

=item * workspace_id =E<gt> $workspace_id

=back

It can I<optionally> include:

=over

=item * role_id =E<gt> $role_id

=item * is_selected =E<gt> 1 or 0

=back

If no C<$role_id> is provided, a default role will be used instead.  Refer to
C<SetDefaultValues()> for details.

=item B<$factory-E<gt>SetDefaultValues(\%proto_uwr)>

Sets default values into the provided C<\%proto_uwr>, prior to creation of the
record in the DB.

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
