package Socialtext::Group;
# @COPYRIGHT@

use Moose;
use Carp qw(croak);
use List::Util qw(first);
use Socialtext::AppConfig;
use Socialtext::MultiCursor;
use Socialtext::Timer;
use Socialtext::SQL qw(:exec);
use Socialtext::UserGroupRoleFactory;
use Socialtext::GroupWorkspaceRoleFactory;
use namespace::clean -except => 'meta';

###############################################################################
# The "Group" equivalent to a User Homunculus.
has 'homunculus' => (
    is => 'ro', isa => 'Socialtext::Group::Homunculus',
    required => 1,
    handles => [qw(
        group_id
        driver_key
        driver_name
        driver_id
        driver_unique_id
        driver_group_name
        primary_account_id
        primary_account
        creation_datetime
        created_by_user_id
        creator
        cached_at
        is_system_managed
        expire
        can_update_store
        update_store
        delete
    )],
);

###############################################################################
sub Drivers {
    my $drivers = Socialtext::AppConfig->group_factories();
    return split /;/, $drivers;
}

###############################################################################
sub ByAccountId {
    my $class   = shift;
    my %p       = @_;
    my $sql = qq{
        SELECT group_id
          FROM groups
         WHERE primary_account_id = ?
         ORDER BY driver_group_name;
    };
    return $class->_GroupCursor(
        $sql, [qw( account_id )], %p
    );
}

sub _GroupCursor {
    my ($class, $sql, $interpolations, %p) = @_;

    Socialtext::Timer->Continue('group_cursor');

    my $sth    = sql_execute($sql, @p{ @{$interpolations} });
    my $cursor = Socialtext::MultiCursor->new(
        iterables => [ $sth->fetchall_arrayref ],
        apply => sub {
            my $row = shift;
            return Socialtext::Group->GetGroup(group_id => $row->[0]);
        },
    );

    Socialtext::Timer->Pause('group_cursor');
    return $cursor;
}

###############################################################################
sub Factory {
    my ($class, %p) = @_;
    my $driver_name = $p{driver_name};
    my $driver_id   = $p{driver_id};
    my $driver_key  = $p{driver_key};
    if ($driver_key) {
        ($driver_name, $driver_id) = split /:/, $driver_key;
    }

    my $driver_class = join '::', $class->base_package(), $driver_name, 'Factory';
    eval "require $driver_class";
    die "couldn't load $driver_class: $@" if $@;
    return $driver_class->new(driver_key => $driver_key);
}

###############################################################################
sub Create {
    my ($class, $proto_group) = @_;

    # find first updateable factory
    my $factory =
        first { $_->can_update_store }
        map { $class->Factory(driver_key => $_) }
        $class->Drivers();
    unless ($factory) {
        die "No writable Group factories configured.";
    }

    # ask that factory to create the Group Homunculus
    my $homey = $factory->Create($proto_group);
    my $group = Socialtext::Group->new(homunculus => $homey);
    return $group;
}

###############################################################################
sub GetGroup {
    my $class = shift;
    my %p = (@_==1) ? %{+shift} : @_;

    # ask all of the configured Group Factories if they know about this Group
    my @drivers = $class->Drivers();
    foreach my $driver_key (@drivers) {
        my $factory = $class->Factory(driver_key => $driver_key);
        my $homey   = $factory->GetGroupHomunculus(%p);
        if ($homey) {
            return Socialtext::Group->new(homunculus => $homey);
        }
    }

    # nope, didn't find it
    return;
}

###############################################################################
# Base package for Socialtext Group infrastructure.
sub base_package {
    return __PACKAGE__;
}

###############################################################################
sub users {
    my $self = shift;
    return Socialtext::UserGroupRoleFactory->ByGroupId(
        $self->group_id,
        sub { shift->user(); },
    );
}

###############################################################################
sub add_user {
    my $self = shift;
    my %p    = @_;
    my $user = $p{user} || croak "cannot add_user without 'user' parameter";
    my $role = $p{role} || Socialtext::UserGroupRoleFactory->DefaultRole();

    my $ugr = $self->_ugr_for_user($user);
    if ($ugr) {
        $ugr->update( { role_id => $role->role_id } );
    }
    else {
        $ugr = Socialtext::UserGroupRoleFactory->Create( {
            user_id  => $user->user_id,
            group_id => $self->group_id,
            role_id  => $role->role_id,
        } );
    }

    return $ugr;
}

###############################################################################
sub remove_user {
    my $self = shift;
    my %p    = @_;
    my $user = $p{user} || croak "cannot remove_user with 'user' parameter";

    my $ugr = $self->_ugr_for_user($user);
    return unless $ugr;

    Socialtext::UserGroupRoleFactory->Delete($ugr);
}

###############################################################################
sub has_user {
    my $self = shift;
    my $user = shift;
    my $ugr  = $self->_ugr_for_user($user);
    return $ugr ? 1 : 0;
}

###############################################################################
sub role_for_user {
    my $self = shift;
    my $user = shift;
    my $ugr  = $self->_ugr_for_user($user);
    return unless $ugr;
    return $ugr->role();
}

###############################################################################
sub _ugr_for_user {
    my $self = shift;
    my $user = shift;
    my $ugr  = Socialtext::UserGroupRoleFactory->GetUserGroupRole(
        user_id  => $user->user_id,
        group_id => $self->group_id,
    );
    return $ugr;
}

###############################################################################
sub workspaces {
    my $self = shift;
    return Socialtext::GroupWorkspaceRoleFactory->ByGroupId(
        $self->group_id,
        sub { shift->workspace },
    );
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

Socialtext::Group - Socialtext Group object

=head1 SYNOPSIS

  use Socialtext::Group;

  # get a list of all registered Group factories/drivers
  @drivers = Socialtext::Group->Drivers();

  # instantiate a specific Group Factory
  $factory = Socialtext::Group->Factory(driver_key => $driver_key);
  $factory = Socialtext::Group->Factory(
    driver_name => $driver_name,
    driver_id   => $driver_id,
    );

  # create a new Group
  $group = Socialtext::Group->Create( \%proto_group );

  # retrieve an existing Group
  $group = Socialtext::Group->GetGroup(group_id => $group_id);

  # get the Users in the Group
  $user_multicursor = $group->users();

  # get the Workspaces the Group has access to
  $ws_multicursor = $group->workspaces();

  # add a User to the Group
  $group->add_user(user => $user, role => $role);

  # remove a User from a Group
  $group->remove_user(user => $user);

  # check if a User already exists in the Group
  $exists = $group->has_user($user);

  # get the Role for a User in the Group
  $role = $group->role_for_user($user);

=head1 DESCRIPTION

This class provides methods for dealing with Groups.

=head1 METHODS

=over

=item B<Socialtext::Group-E<gt>Drivers()>

Returns a list of registered Group factories/drivers back to the caller, as a
list of their "driver_key"s.  These "driver_key"s can be used to instantiate a
factory by calling C<Socialtext::Group-E<gt>Factory()>.

=item B<Socialtext::Group-E<gt>Factory(%opts)>

Instantiates a Group Factory, as defined by the provided C<%opts>.

Valid instantiation C<%opts> include:

=over

=item driver_key =E<gt> $driver_key

Factory instantiation via driver key (which contains both the name of the
driver and its id).

=item driver_name =E<gt> $driver_name, driver_id =E<gt> $driver_id

Factory instantiation via driver name+id.

=back

=item B<Socialtext::Group-E<gt>Create(\%proto_group)>

Attempts to create a Group with the given C<\%proto_group> hash-ref, returning
the newly created Group object back to the caller.  The Group will be created
in the first updateable Group Factory store, as found in the list of
C<Drivers()>.

For more information on the required attributes for a Group, please refer to
L<Socialtext::Group::Factory> and its C<Create()> method.

=item B<Socialtext::Group-E<gt>GetGroup($key, $val)>

Looks for a Group matching the given C<$key/$val> pair, and returns a
C<Socialtext::Group> object for that Group if one exists.

Valid C<$key>s include:

=over

=item group_id

=back

=item B<Socialtext::Group-E<gt>ByAccountId(account_id=E<gt>$acct_id)>

Returns a C<Socialtext::MultiCursor> containing a list of all of the Groups
that exist within the given Account, ordered by "Group Name".

=item B<Socialtext::Group-E<gt>base_package()>

Returns the Perl namespace underneath which all of the Group related modules
can be found.

=item B<$group-E<gt>users()>

Returns a C<Socialtext::MultiCursor> of Users who have a Role in this Group.

=item B<$group-E<gt>add_user(user=E<gt>$user, role=E<gt>$role)>

Adds a given C<$user> to the Group with the specified C<$role>.  If no
C<$role> is provided, a default Role will be used instead.

If the User B<already> has a Role in the Group, the User's Role will be
B<updated> to match the given C<$role>.

=item B<$group-E<gt>remove_user(user=E<gt>$user)>

Removes any Role that the given C<$user> may have in the Group.  If the User
has no Role in the Group, this method does nothing.

=item B<$group-E<gt>has_user($user)>

Checks to see if the given C<$user> has a Role in this Group, returning true
if the User has a Role, false otherwise.

=item B<$group-E<gt>role_for_user($user)>

Returns a C<Socialtext::Role> object representing the Role that the given
C<$user> has in this Group.  If the User has no Role in the Group, this method
returns empty-handed.

=item B<$group-E<gt>workspaces()>

Returns a C<Socialtext::MultiCursor> of Workspaces that this Group has a Role
in.

=item B<$group-E<gt>homunculus()>

Returns the Group Homunculus for the Group.

=item B<$group-E<gt>group_id()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>driver_key()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>driver_name()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>driver_id()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>driver_unique_id()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>driver_group_name()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>primary_account_id()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>primary_account()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>creation_datetime()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>created_by_user_id()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>creator()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>cached_at()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>is_system_managed()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>expire()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>can_update_store()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>update_store()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>delete()>

Delegated to C<Socialtext::Group::Homunculus>.

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
