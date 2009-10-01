package Socialtext::Group;
# @COPYRIGHT@

use Moose;
use Carp qw(croak);
use List::Util qw(first);
use Socialtext::AppConfig;
use Socialtext::Cache;
use Socialtext::Log qw(st_log);
use Socialtext::MultiCursor;
use Socialtext::Timer;
use Socialtext::SQL qw(:exec :time);
use Socialtext::SQL::Builder qw(sql_abstract);
use Socialtext::Pluggable::Adapter;
use Socialtext::UserGroupRoleFactory;
use Socialtext::GroupAccountRoleFactory;
use Socialtext::GroupWorkspaceRoleFactory;
use Socialtext::GroupWorkspaceRole;
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

has $_.'_count' => (
    is => 'rw', isa => 'Int',
    lazy_build => 1
) for qw(user workspace account);

###############################################################################
sub Drivers {
    my $drivers = Socialtext::AppConfig->group_factories();
    return split /;/, $drivers;
}

###############################################################################
sub Count {
    my $class   = shift;
    my %p       = @_;
    return $class->All(@_, _count_only => 1);
}

sub ByAccountId {
    my $class   = shift;
    my %p       = @_;
    croak "needs an account_id" unless $p{account_id};
    return $class->All(@_);
}

sub ByWorkspaceId {
    my $class   = shift;
    my %p       = @_;
    croak "needs a workspace_id" unless $p{workspace_id};
    return $class->All(@_);
}

sub All {
    my $class = shift;
    my %p     = @_;

    my $from = 'groups';
    my @cols = ('group_id');
    my @where;
    my $order;

    Socialtext::Timer->Continue('group_cursor');

    my $ob = $p{order_by} || 'driver_group_name';
    $p{sort_order} ||= 'ASC';

    push @where, primary_account_id => $p{primary_account_id}
        if $p{primary_account_id};

    push @where, driver_key => $p{driver_key}
        if $p{driver_key};

    if ($p{account_id}) {
        $from .= q{ JOIN group_account_role gar USING (group_id) };
        push @where, 'gar.account_id' => $p{account_id};
    }

    if ($p{workspace_id}) {
        $from .= q{ JOIN group_workspace_role gwro USING (group_id) };
        push @where, 'gwro.workspace_id' => $p{workspace_id};
    }

    if (!$p{_count_only} && ($p{account_id} || $p{workspace_id})) {
        $from .= q{ JOIN "Role" rrr using (role_id) };
        push @cols, 'rrr.name AS role_name';
    }

    if ($p{_count_only}) {
        @cols = ('COUNT(group_id) as count');
        $order = undef; # force no ORDER BY
    }
    else {
        if ($ob =~ /^\w+$/ and $p{sort_order} =~ /^(?:ASC|DESC)$/i) {
            $order = "$ob $p{sort_order}";
            $order .= ", driver_group_name ASC"
                unless ($ob eq 'driver_group_name' || $ob eq 'group_id');
            $order .= ", group_id ASC" unless ($ob eq 'group_id');
        }

        if ($p{include_aggregates}) {
            push @cols, 'COALESCE(user_count,0) AS user_count';
            $from .= q{ LEFT JOIN (
                    SELECT group_id, COUNT(distinct user_id) AS user_count
                    FROM user_group_role
                    GROUP BY group_id
                ) ugr USING (group_id) };

            push @cols, 'COALESCE(workspace_count,0) AS workspace_count';
            $from .= q{ LEFT JOIN (
                    SELECT group_id, COUNT(distinct workspace_id) AS workspace_count
                    FROM group_workspace_role
                    GROUP BY group_id
                ) gwr USING (group_id) };
        }

        if ($ob eq 'creator') {
            push @cols, 'users.email_address AS creator';
            $from .= q{ JOIN users ON (groups.created_by_user_id = user_id) };
        }
        elsif ($ob eq 'primary_account') {
            push @cols, '"Account".name AS primary_account';
            $from .= q{ JOIN "Account" ON (
                groups.primary_account_id="Account".account_id) };
        }
    }

    my ($sql, @bind) = sql_abstract()->select(
        \$from, \@cols, \@where, $order, $p{limit}, $p{offset});
    my $sth = sql_execute($sql, @bind);

    Socialtext::Timer->Pause('group_cursor');

    if ($p{_count_only}) {
        my ($count) = $sth->fetchrow_array();
        return $count;
    }

    my $apply;
    if ($p{_apply_gwr}) {
        my $ws = Socialtext::Workspace->new(workspace_id => $p{workspace_id});
        $apply = sub {
            my $row = shift;
            my $role = Socialtext::Role->new(name => $row->{role_name});
            my $group = Socialtext::Group->GetGroup(group_id=>$row->{group_id});
            if ($p{include_aggregates}) {
                $group->$_($row->{$_}) for qw(user_count workspace_count);
            }
            return Socialtext::GroupWorkspaceRole->new(
                workspace_id => $ws->workspace_id,
                group_id => $group->group_id,
                role_id => $role->role_id,
                workspace => $ws,
                group => $group,
                role => $role
            );
        };
    }
    else {
        $apply = sub {
            my $row = shift;
            my $group = Socialtext::Group->GetGroup(group_id=>$row->{group_id});
            if ($p{include_aggregates}) {
                $group->$_($row->{$_}) for qw(user_count workspace_count);
            }
            return $group;
        };
    }
    my $cursor = Socialtext::MultiCursor->new(
        iterables => [ $sth->fetchall_arrayref({}) ],
        apply => $apply,
    );

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
    else {
        $driver_key = join ':', $driver_name, $driver_id;
    }

    my $driver_class = join '::', $class->base_package(), $driver_name, 'Factory';
    eval "require $driver_class";
    die "couldn't load $driver_class: $@" if $@;

    my $factory = eval { $driver_class->new(driver_key => $driver_key) };
    if ($@) {
        st_log->warning( $@ );
    }
    return $factory;
}

###############################################################################
sub Create {
    my ($class, $proto_group) = @_;

    # find first updateable factory
    my $factory =
        first { $_->can_update_store }
        grep  { defined $_ }
        map   { $class->Factory(driver_key => $_) }
        $class->Drivers();
    unless ($factory) {
        die "No writable Group factories configured.";
    }

    # ask that factory to create the Group Homunculus
    my $homey = $factory->Create($proto_group);
    my $group = Socialtext::Group->new(homunculus => $homey);

    # make sure the GAR gets created
    my $adapter = Socialtext::Pluggable::Adapter->new;
    $adapter->make_hub(Socialtext::User->SystemUser());
    $adapter->hook(
        'nlw.add_group_account_role',
        $group->primary_account, $group, Socialtext::Role->Member(),
    );

    return $group;
}

###############################################################################
sub GetGroup {
    my $class = shift;
    my %p = (@_==1) ? %{+shift} : @_;

    # Allow for lookups by "Group Id" to be cached.
    if ((scalar keys %p == 1) && (exists $p{group_id})) {
        my $cached = $class->cache->get($p{group_id});
        return $cached if $cached;
    }

    # Get the list of Drivers that the Group _could_ be found in; if we were
    # given a Driver Key explicitly then use that, otherwise go searching for
    # the Group in the list of configured Drivers.
    my @drivers = $p{driver_key} || $class->Drivers();

    # Go find the Group
    foreach my $driver_key (@drivers) {
        # instantiate the Group Factory, skipping if Factory doesn't exist
        my $factory = $class->Factory(driver_key => $driver_key);
        next unless $factory;

        # see if this Factory knows about the Group
        my $homey = $factory->GetGroupHomunculus(%p);
        if ($homey) {
            my $group = Socialtext::Group->new(homunculus => $homey);
            $class->cache->set( $group->group_id, $group );
            return $group;
        }
    }

    # nope, didn't find
    return;
}

{
    # IN-MEMORY cache of Groups, by Group Id.
    my $CacheByGroupId;
    sub cache {
        $CacheByGroupId ||= Socialtext::Cache->cache('group:group_id');
        return $CacheByGroupId;
    }
}

###############################################################################
# Peek at the Group's attrs without auto_vivifying.
sub GetProtoGroup {
    my $class = shift;
    my %p = (@_==1) ? %{+shift} : @_;

    my @drivers = $p{driver_key} || $class->Drivers();
    foreach my $driver_key (@drivers) {
        # instantiate the Group Factory, skipping if Factory doesn't exist
        my $factory = $class->Factory(driver_key => $driver_key);
        next unless $factory;

        my $proto = $factory->_get_cached_group( \%p );
        return undef unless defined $proto;

        $proto->{cached_at} = sql_parse_timestamptz( $proto->{cached_at} );
        return $proto;
    }

    # nope, didn't find
    return undef;
}

###############################################################################
# Base package for Socialtext Group infrastructure.
use constant base_package => __PACKAGE__;

###############################################################################
sub users {
    my $self = shift;

    return Socialtext::UserGroupRoleFactory->ByGroupId(
        $self->group_id,
        sub { shift->user(); },
    );
}

###############################################################################
sub accounts {
    my $self = shift;

    return Socialtext::GroupAccountRoleFactory->ByGroupId(
        $self->group_id,
        sub { shift->account(); },
    );
}

###############################################################################
sub user_ids {
    my $self = shift;
    my $cursor = Socialtext::UserGroupRoleFactory->ByGroupId(
        $self->group_id,
        sub { shift->user_id() },
    );
    return [ $cursor->all ];
}

###############################################################################
sub _build_user_count {
    return shift->users->count;
}

###############################################################################
sub _build_account_count {
    my $self = shift;
    my $mc = Socialtext::GroupAccountRoleFactory->ByGroupId($self->group_id);
    return $mc->count;
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
    my $ugr  = Socialtext::UserGroupRoleFactory->Get(
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

###############################################################################
sub to_hash {
    my $self = shift;
    my %opts = @_;

    my $hash = {
        group_id => $self->group_id,
        name => $self->driver_group_name,
        user_count => $self->user_count,
        workspace_count => $self->workspace_count,
    };

    if ($opts{show_members}) {
        $hash->{members} = $self->users_as_minimal_arrayref;
    }

    return $hash;
}

sub users_as_minimal_arrayref {
    my $self = shift;

    my $members = [];
    my $user_cursor = $self->users;
    while (my $u = $user_cursor->next) {
        push @$members, $u->to_hash(minimal => 1);
    }
    return $members;
}

sub _build_workspace_count {
    return shift->workspaces->count;
}

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

  # get the User Ids for the Users in the Group
  $user_id_aref = $group->user_ids();

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

  # get cached counts
  $n = $group->user_count;
  $n = $group->workspace_count;

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

=item B<Socialtext::Group-E<gt>GetGroup(\%proto_group)>

Looks for a Group matching the provided C<\%proto_group> key/value pairs, and
returns a C<Socialtext::Group> object for that Group if one exists.

The C<\%proto_group> hash-ref B<must> contain sufficient information in order
to I<uniquely> identify a single Group in the database.

Please refer to the primary and unique key definitions in
C<Socialtext::Group::Homunculus> for more information on which sets of columns
can be used to uniquely identify a Group record.

=item B<Socialtext::Group-E<gt>All(PARAMS)>

Returns a C<Socialtext::MultiCursor> containing all Groups.

Accepts the following PARAMS:

=over

=item account_id => $account_id

Restricts results to only contain those Groups that have the provided
C<$account_id> as their Primary Account Id.

=item driver_key => $driver_key

Restricts results to only contain those Groups that were created by the Group
Factory identified by the given C<$driver_key>.

=item order_by => $field

Orders the results on the given C<$field>, which can be any one of:

=over

=item * any of the columns in the "groups" table,

=item * "creator", the e-mail address of the creating User,

=item * "primary_account", the name of the Group's Primary Account.

=item * "user_count", the count of Users in the Group

Requires that C<include_aggregates> be passed through (see below).

=item * "workspace_count", the count of Workspaces the Group is a member of

Requires that C<include_aggregates> be passed through (see below).

=back

By default, the Groups are returned ordered by their Group Name.

=item sort_order => (ASC|DESC)

Specifies that the Groups should be returned in ascending or descending order.

=item include_aggregates => 1

Specifies that the C<Socialtext::Group> objects returned should B<already>
have their "user_count" and "workspace_count" attributes pre-calculated.

By default, you'll get back Group objects that you could call to calculate the
counts on, but if you know you're going to need this then you can optimize by
asking for those aggregates to be pre-calculated.

Having these aggregates pre-calculated B<also> allows for you to sort based on
the aggregate values.

=item limit => N, offset => N

For paging through a long list of groups.

=back

=item B<Socialtext::Group-E<gt>ByAccountId(PARAMS)>

Returns a C<Socialtext::MultiCursor> containing a list of all of the Groups
that have the specified Account as their Primary Account.

Accepts the same PARAMS as C<All()> above, but B<requires> that an
C<account_id> parameter be provided to specify the Primary Account Id that we
should be pulling up Groups for.

This method is basically a helper method for C<All()> above but which ensures
that you've actually passed through an C<account_id> parameter.

=item B<Socialtext::Group-E<gt>Count(PARAMS)>

Returns a count of Groups based on PARAMS (which are the same as for C<All()>
above).

=item B<Socialtext::Group-E<gt>GetProtoGroup($key, $val)>

Looks for group matching the give C<$key/$val> pair, and returns a
hashref for the group's attributes.

Uses the same C<$key> args as C<Socialtext::Group-E<gt>GetGroup()>.

=item B<Socialtext::Group-E<gt>base_package()>

Returns the Perl namespace underneath which all of the Group related modules
can be found.

=item B<$group-E<gt>users()>

Returns a C<Socialtext::MultiCursor> of Users who have a Role in this Group.

=item B<$group-E<gt>user_ids()>

Returns a list-ref containing the User Ids of the Users who have a Role in
this Group.

=item B<$group-E<gt>user_count>

Returns a B<cached> count of Users who have a Role in this Group

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

=item B<$group-E<gt>workspace_count>

Returns a B<cached> count of Workspaces in which this Group has a Role

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
