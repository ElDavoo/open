package Socialtext::Workspace::Roles;
# @COPYRIGHT@

use strict;
use warnings;
use Socialtext::MultiCursor;
use Socialtext::SQL qw(:exec);
use Socialtext::User;
use Socialtext::Validate qw(validate SCALAR_TYPE BOOLEAN_TYPE ARRAYREF_TYPE);
use Readonly;

###############################################################################
# Common SQL UNIONs used to get one type of Id when we've got another.
#
# *REQUIRES* that you pass in need Id as a binding, *twice*.
our $SQL_UNION_USER_ID_BY_WS_ID = qq{
    (   SELECT user_id
          FROM users
          JOIN "UserWorkspaceRole" uwr USING (user_id)
         WHERE uwr.workspace_id = ?
    )
    UNION ALL
    (   SELECT user_id
          FROM users
          JOIN user_group_role ugr USING (user_id)
          JOIN group_workspace_role gwr USING (group_id)
          WHERE gwr.workspace_id = ?
    )
};

our $SQL_UNION_WS_ID_BY_USER_ID = qq{
    (   SELECT uwr.workspace_id
          FROM "UserWorkspaceRole" uwr
         WHERE uwr.user_id = ?
    )
    UNION ALL
    (   SELECT gwr.workspace_id
          FROM group_workspace_role gwr
          JOIN user_group_role ugr USING (group_id)
         WHERE ugr.user_id = ?
    )
};

###############################################################################
# Get a MultiCursor of the Users that have a Role in a given Workspace (either
# directly as an UWR, or indirectly as an UGR+GWR).
#
# The list of Users is de-duped; if a User has multiple Roles in the Workspace
# they only appear _once_ in the resulting MultiCursor.
sub UsersByWorkspaceId {
    my $class = shift;
    my %p     = @_;
    my $ws_id = $p{workspace_id};

    my $sql = qq{
        SELECT user_id, driver_username
          FROM users
         WHERE user_id IN ( $SQL_UNION_USER_ID_BY_WS_ID )
         ORDER BY driver_username
    };

    my $sth = sql_execute($sql, $ws_id, $ws_id);
    return Socialtext::MultiCursor->new(
        iterables => [ $sth->fetchall_arrayref ],
        apply => sub {
            my $row = shift;
            return Socialtext::User->new(user_id => $row->[0]);
        },
    );
}

###############################################################################
# Get the Count of Users that have a Role in a given Workspace (either
# directly as an UWR, or indirectly as an UGR+GWR).
sub CountUsersByWorkspaceId {
    my $class = shift;
    my %p     = @_;
    my $ws_id = $p{workspace_id};

    my $sql = qq{
        SELECT COUNT(user_id)
          FROM users
         WHERE user_id IN ( $SQL_UNION_USER_ID_BY_WS_ID )
    };

    my $count = sql_singlevalue($sql, $ws_id, $ws_id);
    return $count;
}

###############################################################################
# Check to see if a User has a specific Role in the Workspace (either directly
# as an UWR, or indirectly as an UGR+GWR)
sub UserHasRoleInWorkspace {
    my $class = shift;
    my %p     = @_;
    my $user  = $p{user};
    my $role  = $p{role};
    my $ws    = $p{workspace};

    my $user_id = $user->user_id();
    my $role_id = $role->role_id();
    my $ws_id   = $ws->workspace_id();

    my $sql = qq{
        SELECT 1
          FROM users
         WHERE users.user_id = ?
           AND (
                    ( EXISTS (
                        SELECT user_id
                          FROM "UserWorkspaceRole" AS uwr
                         WHERE uwr.user_id = users.user_id
                           AND uwr.role_id = ?
                           AND uwr.workspace_id = ?
                    ) )
                    OR
                    ( EXISTS (
                        SELECT gwr.group_id
                          FROM group_workspace_role AS gwr
                         WHERE gwr.role_id = ?
                           AND gwr.workspace_id = ?
                           AND gwr.group_id IN (
                                  SELECT ugr.group_id
                                    FROM user_group_role AS ugr
                                   WHERE ugr.user_id = ?
                             )
                    ) )
               )
    };
    my $is_ok = sql_singlevalue(
        $sql,
        ($user_id, $role_id, $ws_id),
        ($role_id, $ws_id, $user_id)
    );
    return $is_ok || 0;
}

###############################################################################
# Get the list of Roles that this User has in the given Workspace (either
# directly as UWRs, or indirectly as UGR+GWRs)
sub RolesForUserInWorkspace {
    my $class = shift;
    my %p     = @_;
    my $user  = $p{user};
    my $ws    = $p{workspace};

    my $user_id = $user->user_id();
    my $ws_id   = $ws->workspace_id();

    my $sql = qq{
        SELECT DISTINCT(role_id)
          FROM (
                ( SELECT uwr.role_id
                    FROM "UserWorkspaceRole" AS uwr
                   WHERE uwr.user_id = ?
                     AND uwr.workspace_id = ?
                )
                UNION
                ( SELECT gwr.role_id
                    FROM group_workspace_role AS gwr
                    JOIN user_group_role ugr USING (group_id)
                   WHERE ugr.user_id = ?
                     AND gwr.workspace_id = ?
                )
          ) AS all_his_roles
    };
    my $sth = sql_execute(
        $sql,
        ($user_id, $ws_id),
        ($user_id, $ws_id),
    );

    # turn the results into a list of Roles
    my @all_roles =
        map  { Socialtext::Role->new(role_id => $_->[0]) }
        @{ $sth->fetchall_arrayref() };

    # sort it from highest->lowest effectiveness
    my @sorted =
        reverse Socialtext::Role->SortByEffectiveness(roles => \@all_roles);

    return wantarray ? @sorted : shift @sorted;
}

###############################################################################
# Get a MultiCursor of the Workspaces that a given User has a Role in (either
# directly as an UWR, or indirectly as an UGR+GWR).
#
# The list of Users is de-duped; if the User has multiple Roles in a Workspace
# they only appear _once_ in the resulting MultiCursor.
{
    # order_by and sort_order are currently a part of the spec here,
    # but are not actually being used. This is so we can pass paging
    # arguments in from the control panel.
    Readonly my $spec => {
        exclude       => ARRAYREF_TYPE(default => []),
        limit         => SCALAR_TYPE(default   => ''),
        offset        => SCALAR_TYPE(default   => ''),
        order_by      => SCALAR_TYPE(default   => 'name'),
        sort_order    => SCALAR_TYPE(default   => 'asc'),
        user_id       => SCALAR_TYPE,
    };
    sub WorkspacesByUserId {
        my $class   = shift;
        my %p       = validate(@_, $spec);
        my $user_id = $p{user_id};

        my $exclude_clause = '';
        if (@{ $p{exclude} }) {
            my $wksps = join(',', @{ $p{exclude} });
            $exclude_clause = "AND workspace_id NOT IN ($wksps)";
        }

        my $limit_and_offset = '';
        if ( $p{limit} ) {
            $limit_and_offset = "LIMIT $p{limit}";
            $limit_and_offset .= " OFFSET $p{offset}" if $p{offset};
        }

        my $sql = qq{
            SELECT "Workspace".workspace_id
              FROM "Workspace"
             WHERE workspace_id IN ( $SQL_UNION_WS_ID_BY_USER_ID )
             $exclude_clause
             ORDER BY "Workspace".name $p{sort_order}
             $limit_and_offset
        };
        my $sth = sql_execute($sql, $user_id, $user_id);

        return Socialtext::MultiCursor->new(
            iterables => [ $sth->fetchall_arrayref() ],
            apply => sub {
                my $row = shift;
                return Socialtext::Workspace->new(workspace_id => $row->[0]);
            }
        );
    }
}

1;

=head1 NAME

Socialtext::Workspace::Roles - User/Workspace Role helper methods

=head1 SYNOPSIS

  use Socialtext::Workspace::Roles;

  # Get Users that have _some_ Role in a WS
  $cursor = Socialtext::Workspace::Roles->UsersByWorkspaceId(
    workspace_id => $ws_id
  );

  # Get Count of Users that have _some_ Role in a WS
  $count = Socialtext::Workspace::Roles->CountUsersByWorkspaceId(
    workspace_id => $ws_id
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
    user_id => $user_id
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

=item B<Socialtext::Workspace::Roles-E<gt>UsersByWorkspaceId(workspace_id =E<gt> $ws_id)>

Returns a C<Socialtext::MultiCursor> containing all of the Users that have a
Role in the Workspace represented by the given C<workspace_id>.

The list of Users returned is I<already> de-duped (so any User appears once
and only once in the list), and is ordered by Username.

=item B<Socialtext::Workspace::Roles-E<gt>CountUsersByWorkspaceId(workspace_id =E<gt> $ws_id)>

Returns the count of Users that have a Role in the Workspace represented by
the given C<workspace_id>.

This method has been optimized so that it doesn't have to fetch B<all> of the
Users from the DB in order to count them up; we just issue the query and take
the count of the results.

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

=back

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
