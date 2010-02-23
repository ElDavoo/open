package Socialtext::Workspace::Roles;
# @COPYRIGHT@

use strict;
use warnings;
use Socialtext::Cache;
use Socialtext::MultiCursor;
use Socialtext::SQL qw(:exec);
use Socialtext::User;
use Socialtext::UserSet qw/:const/;
use Socialtext::Validate qw(validate SCALAR_TYPE BOOLEAN_TYPE ARRAYREF_TYPE);
use Readonly;

###############################################################################
# Get a MultiCursor of the Users that have a Role in a given Workspace (either
# directly as an UWR, or indirectly as an UGR+GWR).
#
# The list of Users is de-duped; if a User has multiple Roles in the Workspace
# they only appear _once_ in the resulting MultiCursor.
sub UsersByWorkspaceId {
    my $class  = shift;
    my %p      = @_;
    my $ws_id  = $p{workspace_id};
    my $direct = defined $p{direct} ? $p{direct} : 0;

    my $uwr_table = $direct
        ? 'user_set_include'
        : 'user_set_path';
    my $ws_uset_id = $ws_id + WKSP_OFFSET;

    my $sql = qq{
        SELECT DISTINCT user_id, driver_username
          FROM $uwr_table
          JOIN users ON (from_set_id = user_id)
         WHERE into_set_id = ?
         ORDER BY driver_username
    };

    my $sth = sql_execute($sql, $ws_uset_id);
    return Socialtext::MultiCursor->new(
        iterables => [ $sth->fetchall_arrayref ],
        apply     => sub {
            my $row = shift;
            return Socialtext::User->new(user_id => $row->[0]);
        },
    );
}

###############################################################################
# Get the Count of Users that have a Role in a given Workspace (either
# directly as an UWR, or indirectly as an UGR+GWR).
sub CountUsersByWorkspaceId {
    my $class  = shift;
    my %p      = @_;
    my $ws_id  = $p{workspace_id};
    my $direct = defined $p{direct} ? $p{direct} : 0;

    my $uwr_table = $direct
        ? 'user_set_include'
        : 'user_set_path';
    my $ws_uset_id = $ws_id + WKSP_OFFSET;
    my $sql = qq{
        SELECT COUNT(DISTINCT from_set_id)
          FROM $uwr_table
         WHERE into_set_id = ?
           AND from_set_id }.PG_USER_FILTER;

    my $count = sql_singlevalue($sql, $ws_uset_id);
    return $count;
}

###############################################################################
# Check to see if a User has a specific Role in the Workspace (either directly
# as an UWR, or indirectly as an UGR+GWR)
sub UserHasRoleInWorkspace {
    my $class  = shift;
    my %p      = @_;
    my $user   = $p{user};
    my $role   = $p{role};
    my $ws     = $p{workspace};
    my $direct = defined $p{direct} ? $p{direct} : 0;

    my $uwr_table = $direct
        ? 'user_set_include'
        : 'user_set_path';

    my $user_id = $user->user_id();
    my $role_id = $role->role_id();
    my $ws_set_id = $ws->user_set_id();

    my $sql = qq{
        SELECT 1
          FROM $uwr_table
         WHERE from_set_id = ?
           AND into_set_id = ?
           AND role_id = ?
         LIMIT 1
    };
    my $is_ok = sql_singlevalue($sql, $user_id, $ws_set_id, $role_id);
    return $is_ok || 0;
}

###############################################################################
# Get the list of Roles that this User has in the given Workspace (either
# directly as UWRs, or indirectly as UGR+GWRs)
sub RolesForUserInWorkspace {
    my $class  = shift;
    my %p      = @_;
    my $user   = $p{user};
    my $ws     = $p{workspace};
    my $direct = defined $p{direct} ? $p{direct} : 0;
    $direct = $direct ? 1 : 0; # force to only 1 or 0

    my $user_id = $user->user_id();
    my $ws_id   = $ws->workspace_id();
    my $cache_string = "rfuiw-$user_id-$ws_id-$direct";
    if (my $roles = $class->cache->get($cache_string)) {
        return wantarray ? @$roles : $roles->[0];
    }

    my $uwr_table = $direct
        ? 'user_set_include'
        : 'user_set_path';
    my $ws_uset_id = $ws_id + WKSP_OFFSET;
    my $sql = qq{
        SELECT DISTINCT role_id
          FROM $uwr_table
         WHERE from_set_id = ?
           AND into_set_id = ?
    };
    my $sth = sql_execute($sql, $user_id, $ws_uset_id);

    # turn the results into a list of Roles
    my @all_roles =
        map  { Socialtext::Role->new(role_id => $_->[0]) }
        @{ $sth->fetchall_arrayref() };

    # sort it from highest->lowest effectiveness
    my @sorted =
        reverse Socialtext::Role->SortByEffectiveness(roles => \@all_roles);

    $class->cache->set($cache_string => \@sorted);
    return wantarray ? @sorted : $sorted[0];
}

###############################################################################
# Get a MultiCursor of the Workspaces that a given User has a Role in (either
# directly as an UWR, or indirectly as an UGR+GWR).
#
# The list of Workspaces is de-duped; if the User has multiple Roles in a
# Workspace they only appear _once_ in the resulting MultiCursor.
{
    # order_by and sort_order are currently a part of the spec here,
    # but are not actually being used. This is so we can pass paging
    # arguments in from the control panel.
    Readonly my $spec => {
        exclude       => ARRAYREF_TYPE(default => []),
        limit         => SCALAR_TYPE(default   => undef),
        offset        => SCALAR_TYPE(default   => 0),
        order_by      => SCALAR_TYPE(default   => 'name'),
        sort_order    => SCALAR_TYPE(default   => 'asc'),
        user_id       => SCALAR_TYPE,
        direct        => BOOLEAN_TYPE(default => 0),
    };
    sub WorkspacesByUserId {
        my $class      = shift;
        my %p          = validate(@_, $spec);
        my $user_id    = $p{user_id};
        my $limit      = $p{limit};
        my $offset     = $p{offset};
        my $direct     = $p{direct};
        my $exclude    = $p{exclude};
        my $sort_order = $p{sort_order};

        my $uwr_table = $direct
            ? 'user_set_include'
            : 'user_set_path';

        my $exclude_clause = '';
        if (@$exclude) {
            my $wksps
                = join(',', map { $_ + WKSP_OFFSET } grep !/\D/, @$exclude);
            $exclude_clause = "AND into_set_id NOT IN ($wksps)";
        }

        my $sql = qq{
            SELECT w.workspace_id
              FROM "Workspace" w
              JOIN $uwr_table ON (w.user_set_id = into_set_id)
             WHERE from_set_id = ?
             $exclude_clause
             GROUP BY w.workspace_id, w.title
             ORDER BY w.title $sort_order
             LIMIT ? OFFSET ?
        };
        my $sth = sql_execute( $sql, $user_id, $limit, $offset );

        return Socialtext::MultiCursor->new(
            iterables => [ $sth->fetchall_arrayref() ],
            apply     => sub {
                my $row = shift;
                return Socialtext::Workspace->new(workspace_id => $row->[0]);
            }
        );
    }

    sub CountWorkspacesByUserId {
        my $class   = shift;
        my %p       = validate(@_, $spec);
        my $user_id = $p{user_id};
        my $direct  = $p{direct};
        my $exclude = $p{exclude};

        my $exclude_clause = '';
        if (@$exclude) {
            my $wksps = join(',', map { WKSP_OFFSET + $_ } 
                grep !/\D/, @$exclude);
            $exclude_clause = "AND into_set_id NOT IN ($wksps)";
        }

        my $uwr_table = $direct
            ? 'user_set_include'
            : 'user_set_path';
        my $sql = qq{
            SELECT COUNT(DISTINCT(into_set_id))
              FROM $uwr_table
             WHERE from_set_id = ?
               AND into_set_id }.PG_WKSP_FILTER.qq{
             $exclude_clause
        };
        my $count = sql_singlevalue( $sql, $user_id );
        return $count;
    }
}

{
    my $cache;
    sub cache {
        return $cache ||= Socialtext::Cache->cache('ws_roles');
    }
}

1;

=head1 NAME

Socialtext::Workspace::Roles - User/Workspace Role helper methods

=head1 SYNOPSIS

  use Socialtext::Workspace::Roles;

  # Get Users that have _some_ Role in a WS
  $cursor = Socialtext::Workspace::Roles->UsersByWorkspaceId(
    workspace_id => $ws_id,
  );

  # Get Count of Users that have _some_ Role in a WS
  $count = Socialtext::Workspace::Roles->CountUsersByWorkspaceId(
    workspace_id => $ws_id,
  );

  # Most effective Role that User has in Workspace
  $role = Socialtext::Workspace::Roles->RolesForUserInWorkspace(
    user      => $user,
    workspace => $workspace,
  );

  # List of all Roles that User has in Workspace
  @roles = Socialtext::Workspace::Roles->RolesForUserInWorkspace(
    user      => $user,
    workspace => $workspace,
  );

  # List of all Workspaces that User has a Role in
  $cursor = Socialtext::Workspace::Roles->WorkspacesByUserId(
    user_id => $user_id,
  );

  # Get Count of Workspaces that User has _some_ Role in
  $count = Socialtext::Workspace::Roles->CountWorkspacesByUserId(
    user_id => $user_id,
  );

=head1 DESCRIPTION

C<Socialtext::Workspace::Roles> gathers together a series of helper methods to
help navigate the various types of relationships between "Users" and
"Workspaces" under one hood.

Some of these relationships are direct (User->Workspace), while others are
indirect (User->Group->Workspace).  The methods in this module aim to help
flatten the relationships so you don't have to care B<how> the User has the
Role in the given Workspace, only that he has it.

=head1 METHODS

=over

=item B<Socialtext::Workspace::Roles-E<gt>UsersByWorkspaceId(PARAMS)>

Returns a C<Socialtext::MultiCursor> containing all of the Users that have a
Role in the Workspace.

The list of Users returned is I<already> de-duped (so any User appears once
and only once in the list), and is ordered by Username.

Acceptable C<PARAMS> include:

=over

=item workspace_id => $workspace_id

B<Required.>  Id for the Workspace to get the list of Users for.

=item direct => 1|0

A boolean stating whether or not we should only be concerned about Users that
have a B<direct> Role in the Workspace.  By default, Users with either a
direct or an indirect Role are considered.

=back

=item B<Socialtext::Workspace::Roles-E<gt>CountUsersByWorkspaceId(PARAMS)>

Returns the count of Users that have a Role in the Workspace.

This method has been optimized so that it doesn't have to fetch B<all> of the
Users from the DB in order to count them up; we just issue the query and take
the count of the results.

Acceptable C<PARAMS> include:

=over

=item workspace_id => $workspace_id

B<Required.>  Id for the Workspace to get the User count for.

=item direct => 1|0

A boolean stating whether or not we should only be concerned about Users that
have a B<direct> Role in the Workspace.  By default, Users with either a
direct or an indirect Role are considered.

=back

=item B<Socialtext::Workspace::Roles-E<gt>UserHasRoleInWorkspace(PARAMS)>

Checks to see if a given User has a given Role in a given Workspace.  Returns
true if it does, false otherwise.

C<PARAMS> must include:

=over

=item user

User object

=item role

Role object

=item workspace

Workspace object

=back

C<PARAMS> may also include:

=over

=item direct => 1|0

A boolean stating whether or not we should only be concerned about B<direct>
Roles in the Workspace.  By default, direct or indirect Roles are considered.

=back

=item B<Socialtext::Workspace::Roles-E<gt>RolesForUserInWorkspace(PARAMS)>

Returns the Roles that the User has in the given Workspace.

In a I<LIST> context, this is the complete list of Roles that the User has in
the Workspace (either explicit, or via Group membership).  List is ordered
from "highest effectiveness to lowest effectiveness", according to the rules
outlined in L<Socialtext::Role>.

In a I<SCALAR> context, this method returns the highest effective Role that
the User has in the Workspace.

C<PARAMS> must include:

=over

=item user

User object

=item workspace

Workspace object

=back

C<PARAMS> may also include:

=over

=item direct => 1|0

A boolean stating whether or not we should only be concerned about B<direct>
Roles in the Workspace.  By default, direct or indirect Roles are considered.

=back

=item B<Socialtext::Workspace::Roles-E<gt>WorkspacesByUserId(PARAMS)>

Returns a C<Socialtext::MultiCursor> containing all of the Workspaces that a
given User has access to.

The list of Workspaces returned is I<already> de-duped (so any Workspace
appears once and only once in the list), and is ordered by Workspace Name.

Acceptable C<PARAMS> include:

=over

=item user_id

B<Required.>  Specifies the User Id for the User that we are attempting to
find the list of accessible Workspaces for.

=item exclude

A list-ref containing the Workspace Ids for Workspaces that are to be
I<excluded> from the result set.

=item limit

Limits the number of results that are returned in the result set.

=item offset

Specifies an offset into the results to start the result set at.

=item order_by

B<Ignored.>  Provided solely for compatibility with other parts of the system
that hand this through automatically.

The result set is B<always> ordered by Workspace Name.

=item sort_order

Sort ordering; ASCending or DESCending.

=item direct => 1|0

A boolean stating whether or not we should only be concerned with Workspaces
that the User has a B<direct> Role in.  By default, we consider Workspaces
that the User could have a Role in either directly or indirectly.

=back

=item B<Socialtext::Workspace::Roles-E<gt>CountWorkspacesByUserId(PARAMS)>

Returns the count of Workspaces that the User has a Role in.

Accepts the same parameters as C<WorkspacesByUserId()>.

This method has been optimized so that it doesn't have to fetch B<all> of the
Workspaces from the DB in order to count them up; we just issue the query and
take the count of the results.

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
