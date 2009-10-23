package Socialtext::Pluggable::Plugin::Groups;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Pluggable::Plugin';
use Socialtext::Group;
use Socialtext::l10n qw/loc/;
use Socialtext::Role;
use Socialtext::SQL qw(sql_execute);
use Socialtext::User;
use Socialtext::UserGroupRoleFactory;

sub register {
    my $class = shift;

    # Account import/export
    $class->add_hook('nlw.export_account' => 'export_groups_for_account');
    $class->add_hook('nlw.import_account' => 'import_groups_for_account');

    # Workspace import/export
    $class->add_hook(
        'nlw.export_workspace_users' => 'export_group_users_for_workspace');
    $class->add_hook('nlw.export_workspace' => 'export_groups_for_workspace');
    $class->add_hook('nlw.import_workspace' => 'import_groups_for_workspace');
}

sub export_groups_for_account {
    my $self     = shift;
    my $acct     = shift;
    my $data_ref = shift;
    my @groups   = ();

    print loc("Exporting all groups for account '[_1]'...", $acct->name), "\n";

    my $groups = $acct->groups();
    while (my $group = $groups->next()) {
        my $role = $acct->role_for_group(group => $group);
        my $group_data = {
            primary_account_name => $group->primary_account->name,
            driver_group_name    => $group->driver_group_name,
            created_by_username  => $group->creator->username,
            ($role ? (role_name=>$role->name) : ()),
        };
        $group_data->{users} = $self->_get_ugrs_for_export($group);
        push @groups, $group_data;
    }

    $data_ref->{groups} = \@groups;
}

sub import_groups_for_account {
    my $self   = shift;
    my $acct   = shift;
    my $data   = shift;
    my $groups = $data->{groups} || [];

    return unless @$groups;

    print loc("Importing all groups for account '[_1]'...", $acct->name), "\n";

    for my $group_info (@$groups) {
        my $group = _import_group($group_info, $acct);

        # Give the Group an explicit Role in the Account
        if ($group_info->{role_name}) {
            my $role = Socialtext::Role->new(name => $group_info->{role_name});
            unless ($role) {
                warn loc("Missing/unknown Role '[_1]'; using default Role", $group_info->{role_name}) . "\n";
                $role = Socialtext::GroupAccountRoleFactory->DefaultRole();
            }
            $acct->add_group(group => $group, role => $role);
        }

        # Add all of the Users from the export into the Group
        $self->_set_ugrs_on_import($group, $group_info->{users});
    }
}

# Export Users that *ONLY* have transitive (indirect) Roles in the WS (as
# those Users are explicitly ignored in the core Workspace export).
sub export_group_users_for_workspace {
    my $self     = shift;
    my $ws       = shift;
    my $data_ref = shift;
    my $ws_id    = $ws->workspace_id();
    my $role     = 'member';    # lowest Role you can actually assign to User

    # Find all of the Users that *ONLY* have indirect Roles in the WS
    my $sql = qq{
        SELECT u.user_id
          FROM all_user_workspace u
         WHERE u.workspace_id = ?
           AND u.user_id NOT IN
               (    SELECT uwr.user_id
                      FROM user_workspace_role uwr
                     WHERE uwr.workspace_id = ?
               );
    };
    my $sth = sql_execute($sql, $ws_id, $ws_id);

    # Dump the data for each of these "indirect only" Users, and add that to
    # the User data that's being exported.
    while (my $row = $sth->fetchrow_arrayref()) {
        my $user = Socialtext::User->new(user_id => $row->[0]);
        my $dump = $ws->_dump_user_to_hash($user);
        $dump->{role_name} = $role;
        $dump->{indirect}  = 1;
        push @{$data_ref}, $dump;
    }

    # Return the data structure (for *test* purposes)
    return $data_ref;
}

sub export_groups_for_workspace {
    my $self     = shift;
    my $ws       = shift;
    my $data_ref = shift;
    my @groups   = ();

    print loc("Exporting all groups for workspace '[_1]'...", $ws->name), "\n";

    my $gwrs = Socialtext::GroupWorkspaceRoleFactory->ByWorkspaceId(
        $ws->workspace_id,
    );

    while (my $gwr = $gwrs->next()) {
        my $group      = $gwr->group;
        my $group_data = {
            driver_group_name   => $group->driver_group_name,
            created_by_username => $group->creator->username,
            role_name           => $gwr->role->name,
        };
        $group_data->{users} = $self->_get_ugrs_for_export($group);
        push @groups, $group_data;
    }

    $data_ref->{groups} = \@groups;
}

sub import_groups_for_workspace {
    my $self   = shift;
    my $ws     = shift;
    my $data   = shift;
    my $groups = $data->{groups} || [];

    return unless @$groups;

    print loc("Importing all groups for workspace '[_1]'...", $ws->name), "\n";

    for my $group_info (@$groups) {
        my $group = _import_group($group_info, $ws->account);

        # Add all of the Users from the export into the Group
        $self->_set_ugrs_on_import($group, $group_info->{users});

        # Add the Group into the Workspace, using the default Role if we're
        # unable to find the Role that it used to have.
        my $role = Socialtext::Role->new(name => $group_info->{role_name});
        unless ($role) {
            warn loc("Missing/unknown Role '[_1]'; using default Role", $group_info->{role_name}) . "\n";
            $role = Socialtext::GroupWorkspaceRoleFactory->DefaultRole();
        }
        $ws->add_group(group => $group, role => $role);
    }
}

sub _import_group {
    my $group_info = shift;
    my $account    = shift;

    # Find the User who created the Group, falling back on the SystemUser
    # if they can't be found.  This matches the behaviour of Workspace
    # imports (where we assign the WS to the SystemUser).
    my $creator = Socialtext::User->new(
        username => $group_info->{created_by_username}
    );
    $creator ||= Socialtext::User->SystemUser;

    # If the Group was exported along with the name of its Primary Account, it
    # needs to be re-imported back into that Account.
    #
    # NOTE: earlier versions of Account exports did *not* include the Group's
    # Primary Account, and for those cases we're going to import the Group
    # into the Account that we were handed as a param.
    if ($group_info->{primary_account_name}) {
        # Group was exported with a Primary Account; go find/create it.
        $account = Socialtext::Account->new(
            name => $group_info->{primary_account_name},
        );
        unless ($account) {
            $account = Socialtext::Account->create(
                name => $group_info->{primary_account_name},
            );
        }
    }

    # Get/create the Group.
    my $group_params = {
        driver_group_name  => $group_info->{driver_group_name},
        created_by_user_id => $creator->user_id,
        primary_account_id => $account->account_id,
    };
    my $group = Socialtext::Group->GetGroup($group_params)
             || Socialtext::Group->Create($group_params);

    return $group;
}

sub _get_ugrs_for_export {
    my $self  = shift;
    my $group = shift;
    my @users = ();

    my $ugrs = Socialtext::UserGroupRoleFactory->ByGroupId($group->group_id);

    while (my $ugr = $ugrs->next()) {
        my $user = {
            username  => $ugr->user->username,
            role_name => $ugr->role->name,
        };
        push @users, $user;
    }

    return \@users;
}

sub _set_ugrs_on_import {
    my $self  = shift;
    my $group = shift;
    my $data  = shift;

    for my $ugr_data (@$data) {
        my $role = Socialtext::Role->new(name => $ugr_data->{role_name})
            || Socialtext::UserGroupRoleFactory->DefaultRole();

        # Get the User that we're creating the UGR for
        my $user = Socialtext::User->new(username => $ugr_data->{username});
        next unless $user;

        # Don't over-write existing UGRs; if the User already has a Role in
        # the Group then preserve their existing Role.
        next if ($group->has_user($user));

        # Create a new UGR for the User in this Group.
        $group->add_user(user => $user, role => $role);
    }
}

1;

=head1 NAME

Socialtext::Pluggable::Plugin::Groups

=head1 DESCRIPTION

C<Socialtext::Pluggable::Plugin::Groups> provides a means for hooking the
Groups infrastructure into the Socialtext Account import/export facilities.

=head1 METHODS

=over

=item B<Socialtext::Pluggable::Plugin::Groups-E<gt>register()>

Registers the plugin with the system.

=item B<$plugin-E<gt>export_groups_for_account($account, $data_ref)>

Exports information on all of the Groups that live within the provided
C<$account>, by adding group information to the provided C<$data_ref>
hash-ref.

=item B<$plugin-E<gt>import_groups_for_account($account, $data_ref)>

Imports Group information from the provided C<$data_ref> hash-ref, adding the
Groups and their membership lists to the given C<$account>.

If the Group I<already exists> within the Account, any Users/Roles that are
present in the export but that are I<not> present in the Group are added
automatically to the Group; missing Users get added to the Group, but existing
Users and their Roles are untouched.

=item B<$plugin-E<gt>export_group_users_for_workspace($ws, $data_ref)>

Exports information on all of the Users that have access to the provided
C<$ws> but that were I<not> exported automatically by the Workspace itself (as
the Users have B<indirect> Roles in the Workspace) (e.g. a Role in the
Workspace via a Group membership).

=item B<$plugin-E<gt>export_groups_for_workspace($ws, $data_ref)>

Exports information on all of the Groups that have access to the provided
C<$ws>, by adding group information to the provided C<$data_ref> hash-ref.

=item B<$plugin-E<gt>import_groups_for_workspace($ws, $data_ref)>

Imports Group information from the provided C<$data_ref> hash-ref, adding the
Groups and their membership lists to the given C<$ws>.

If the Group I<already exists> within the Account that this Workspace resides
in, any USers/Roles that are present in the export but that are I<not> present
in the Group are added automatically to the Group; missing users get added to
the Group, but existing Users and their Roles are untouched.

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
