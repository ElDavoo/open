package Socialtext::UserGroupRoleFactory;
# @COPYRIGHT@

use MooseX::Singleton;
use Socialtext::Events;
use Socialtext::Log qw(st_log);
use Socialtext::Role;
use Carp qw/croak/;
use Socialtext::SQL::Builder qw/sql_abstract/;
use Socialtext::SQL qw/:exec/;
use namespace::clean -except => 'meta';

with qw(
    Socialtext::Moose::ObjectFactory
    Socialtext::Moose::Does::UserSearch
    Socialtext::Moose::Does::GroupSearch
);

sub SortedResultSet {
    my $self = shift;
    my %opts = @_;

    my @cols = (
        'ugr.user_id AS user_id',
        'ugr.group_id AS group_id',
        'ugr.role_id AS role_id'
    );
    my $from = 'user_group_role ugr';

    my @where;
    @where = ( 'ugr.group_id' => $opts{group_id} ) if $opts{group_id};

    # Determine sort order, adding in table joins if needed.
    my $order;
    if ( my $ob = $opts{order_by} ) {

        if ( lc $ob eq 'username' ) {
            push @cols, 'users.driver_username';
            $from .= ' JOIN users USING ( user_id )';
            $order = 'users.driver_username';
        }
        elsif ( lc $ob eq 'role_name' ) {
            push @cols, '"Role".name';
            $from .= ' JOIN "Role" USING ( role_id )';
            $order = '"Role".name';
        }
        elsif ( lc $ob eq 'source' ) {
            push @cols, 'users.driver_key';
            $from .= ' JOIN users USING ( user_id )';
            $order = 'users.driver_key';
        }
        elsif ( lc $ob eq 'creation_datetime' ) {
            push @cols, 'meta.creation_datetime';
            $from .= ' JOIN "UserMetadata" meta USING ( user_id )';
            $order = 'meta.creation_datetime';
        }
        elsif ( lc $ob eq 'workspace_count' ) {
            push @cols, 'roles.count AS count';
            $from .= q{
                LEFT JOIN (
                    SELECT user_id,
                           COALESCE( COUNT(workspace_id), 0 ) as count
                      FROM all_user_workspace
                     GROUP BY user_id
                ) roles USING ( user_id )
            };
            $order = 'count';
        }
        elsif ( lc $ob eq 'primary_account' ) {
            push @cols, '"Account".name AS account_name';
            $from .= q{
                JOIN "UserMetadata" meta USING ( user_id )
                JOIN "Account" ON meta.primary_account_id = "Account".account_id
            };
            $order = 'account_name';

        }
        else {
            croak "Cannot sort UserGroupRoles by '$ob'";
        }

        $order .= " $opts{sort_order}, ";
    }

    $order .= $self->SqlSortOrder();

    my ($sql, @bind) = sql_abstract()->select(
        \$from, \@cols, \@where, $order, $opts{limit}, $opts{offset});

    my $sth = sql_execute($sql, @bind);
    return $self->Cursor($sth);
}

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
# No-op until we implement recording events for membership changes.
# Also: should $actor be the current_user from hub/rest?
# Also: refactor this and GWRF's _emit_event into a Moose::Role?
#     my ($self, $proto_ugr, $action) = @_;
# 
#     # System managed groups are acted on by the System User.
#     #
#     # non-system managed groups are currently unscoped/unsupported.
#     my $group = Socialtext::Group->GetGroup(group_id => $proto_ugr->{group_id});
#     my $actor = $group->is_system_managed()
#                 ? Socialtext::User->SystemUser()
#                 : die "unable to determine event actor";
# 
#     # Record the event
#     Socialtext::Events->Record( {
#         event_class => 'group',
#         action      => $action,
#         actor       => $actor,
#         context     => $proto_ugr,
#     } );
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
C<SetDefaultValues()> for details.

=item B<$factory-E<gt>SetDefaultValues(\%proto_ugr)>

Sets default values into the provided C<\%proto_ugr>, prior to creation of the
record in the DB.

If the C<\%proto_ugr> does not contain a C<role_id>, a default role will be
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
