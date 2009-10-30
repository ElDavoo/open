package Socialtext::GroupAccountRoleFactory;
# @COPYRIGHT@

use MooseX::Singleton;
use Socialtext::Events;
use Socialtext::Log qw(st_log);
use Socialtext::Role;
use Carp qw/croak/;
use Socialtext::SQL qw/:exec/;
use Socialtext::SQL::Builder qw/sql_abstract/;
use namespace::clean -except => 'meta';

with qw(
    Socialtext::Moose::ObjectFactory
    Socialtext::Moose::Does::GroupSearch
    Socialtext::Moose::Does::AccountSearch
);

sub SortedResultSet {
    my $self = shift;
    my %opts = @_;

    my @cols = (
        'gar.group_id AS group_id',
        'gar.account_id AS account_id',
        'gar.role_id'
    );

    my $from = 'group_account_role gar';

    my @where;
    @where = ( 'gar.group_id' => $opts{group_id} ) if $opts{group_id};

    my $order;
    if ( my $ob = $opts{order_by} ) {

        if ( lc $ob eq 'name' ) {
            push @cols, '"Account".name AS name';
            $from .= ' JOIN "Account" USING ( account_id )';
            $order = 'name';
        }
        elsif ( lc $ob eq 'user_count' ) {
            push @cols, 'roles.count AS count';
            $from .= q{
                LEFT JOIN (
                   SELECT account_id,
                          COALESCE( COUNT(user_id), 0 ) AS count
                     FROM account_user
                    GROUP BY account_id
                ) roles USING ( account_id ) 
            };
            $order = 'count';
        }
        elsif ( lc $ob eq 'workspace_count' ) {
            push @cols, 'ws.count AS count';
            $from .= q{
                LEFT JOIN (
                    SELECT account_id,
                           COALESCE( COUNT(workspace_id), 0 ) AS count
                      FROM "Workspace"
                     GROUP BY account_id
                ) ws USING ( account_id )
            };
            $order = 'count';
        }
        else {
            croak "Cannot sort GroupAccountRoles by '$ob'";
        }

        $opts{sort_order} ||= '';
        $order .= " $opts{sort_order}, ";
    }

    $order .= $self->SqlSortOrder();

    my ($sql, @bind) = sql_abstract()->select(
        \$from, \@cols, \@where, $order, $opts{limit}, $opts{offset});

    my $sth = sql_execute($sql, @bind);
    return $self->Cursor($sth);

}

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
    Socialtext::Role->Member();
}

sub DefaultRoleId {
    DefaultRole()->role_id();
}

sub _emit_event {
    my ($self, $proto_gar, $action) = @_;
    my $actor = Socialtext::User->SystemUser();

    # Record the event
#     Socialtext::Events->Record( {
#         event_class => 'account',
#         action      => $action,
#         actor       => $actor,
#         context     => $proto_gar,
#     } );
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
      group_id   => $group_id,
      account_id => $account_id,
      role_id    => $role_id,
  } );

  # retrieve a GAR
  $gar = $factory->Get(
      group_id   => $group_id,
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

=item B<$factory-E<gt>SortedResultSet( PARAMS )>

Get a result set that is sorted by a particular field. The following options are accepted:

=over

=item * group_id =E<gt> $group_id - Select results only for a given group.

=item * order_by =E<gt> $order - Can be one of a number of things:

=over

=item 'name' - Sort by GAR's Account name.

=item 'user_count' - Sort by GAR's Account user_count.

=item 'workspace_count' - Sort by GAR's Account workspace_count.

=back

=item * sort_order =E<gt> 'asc' or 'desc' - Sort results, the DB default will
be used if not specified here.

=back

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
