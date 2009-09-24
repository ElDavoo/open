package Socialtext::Pluggable::Plugin::AccountMembership;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Pluggable::Plugin';
use Socialtext::Log qw/st_log/;
use Socialtext::UserAccountRoleFactory;
use Socialtext::GroupAccountRoleFactory;

# TEMPORARY
use Socialtext::Role;
use Socialtext::SQL::Builder qw/sql_insert/;
use Socialtext::SQL qw/sql_singlevalue sql_execute/;

=head1 NAME

Socialtext::Pluggable::Plugin::AccountMembership

=head1 SYNOPSIS

  Provides hooks for account membership.
  my $query = $qp->parse($query_string);

=head1 DESCRIPTION

Pluggable plugin for account memberships.

=cut

sub register {
    my $class = shift;

    $class->add_hook('nlw.add_user_account_role'
        => 'add_user_account_role');
    $class->add_hook('nlw.remove_user_account_role'
        => 'remove_user_account_role');

    $class->add_hook('nlw.add_group_account_role'
        => 'add_group_account_role');
    $class->add_hook('nlw.remove_group_account_role'
        => 'remove_group_account_role');
}

sub add_user_account_role {
    my $self    = shift;
    my $account = shift;
    my $user    = shift;
    my $factory = Socialtext::UserAccountRoleFactory->instance();

    my $uar = $factory->Get(
        user_id    => $user->user_id,
        account_id => $account->account_id
    );

    # user has a role, we're set.
    return if $uar;

    # create an 'affiliate' UAR.
    $uar = $factory->Create({
        user_id    => $user->user_id,
        account_id => $account->account_id,
    });
}

sub remove_user_account_role {
    my $self    = shift;
    my $account = shift;
    my $user    = shift;
    my $factory = Socialtext::UserAccountRoleFactory->instance();
    
    # Get UAR.
    my $uar = $factory->Get(
        user_id    => $user->user_id,
        account_id => $account->account_id
    );

    # We should never be without a UAR here, so warn the system before
    # returning.
    unless ( $uar ) {
        st_log->warning("User " . $user->user_id 
            . " is missing role in account " . $account->account_id );
        return;
    }

    # exit if the user still has a role in the account, or if its the primary
    # account.
    return if $self->_user_has_workspace_role($user, $account)
        || $user->primary_account_id == $account->account_id;

    $factory->Delete($uar);
}

sub _user_has_workspace_role {
    my $self    = shift;
    my $user    = shift;
    my $account = shift;

    my $ws_count = sql_singlevalue(q{
        SELECT COUNT("Workspace".workspace_id)
          FROM "Workspace"
          JOIN user_workspace_role USING (workspace_id)
         WHERE user_workspace_role.user_id = ?
           AND "Workspace".account_id = ?
    }, $user->user_id, $account->account_id);

    return ( $ws_count ) ? 1 : 0;
}

sub add_group_account_role {
    my $self    = shift;
    my $account = shift;
    my $group   = shift;
    my $role    = shift || Socialtext::GroupAccountRoleFactory->DefaultRole();
    my $factory = Socialtext::GroupAccountRoleFactory->instance();

    # If we've got a non-Affiliate GAR (e.g. an explicit one; Affiliate is
    # only for secondary relationships), stop here; we've got a Role already.
    my $gar = $factory->Get(
        group_id   => $group->group_id,
        account_id => $account->account_id
    );
    my $role_affiliate = Socialtext::Role->Affiliate();
    return if ($gar && ($gar->role->name ne $role_affiliate->name));

    # Update/Create the GAR as necessary
    if ($gar) {
        # upgrade an "Affiliate" Role to something else
        $gar->update( { role_id => $role->role_id } );
    }
    else {
        $gar = $factory->Create( {
            group_id    => $group->group_id,
            account_id  => $account->account_id,
            role_id     => $role->role_id,
        } );
    }
}

sub remove_group_account_role {
    my $self    = shift;
    my $account = shift;
    my $group   = shift;
    my $role    = shift || Socialtext::GroupAccountRoleFactory->DefaultRole();
    my $factory = Socialtext::GroupAccountRoleFactory->instance();
    
    # Get GAR.
    my $gar = $factory->Get(
        group_id   => $group->group_id,
        account_id => $account->account_id
    );

    # We should never be without a GAR here, so warn the system before
    # returning.
    unless ( $gar ) {
        st_log->warning("group " . $group->group_id 
            . " is missing role in account " . $account->account_id );
        return;
    }

    # Can't ever remove a Role in a Group's Primary Account.
    return if ($account->account_id == $group->primary_account_id);

    # When removing a Group's Role in an Account, we need to consider that we
    # may be downgrading the Group from an explicit "Member" Role to a
    # secondary/implicit "Affiliate" Role (e.g. I'm still a member in a WS in
    # the Account, so I'm still affiliated with the Account).
    #
    # Truth table for this boils down as follows:
    #       has\remove  |   member        affiliate
    #       -----------------------------------------
    #       member      |   downgrade       n/a
    #       affiliate   |   downgrade     downgrade
    #
    # Looking at the above table, the *only* case we need to check for is the
    # "n/a"; all other cases get handled the same except that one.  And, in
    # the "n/a" case, we just "do nothing".
    my $member    = Socialtext::Role->Member();
    my $affiliate = Socialtext::Role->Affiliate();
    if (   ($gar->role->name eq $member->name)
        && ($role->name eq $affiliate->name))
    {
        # has a Member Role, asked to remove Affiliate Role; no-op.
        return;
    }

    # All other cases get handled as "downgrade"; if the Group has a
    # membership in any of the WSs in the Account they get to maintain an
    # "Affiliate" Role, otherwise we remove the Role outright.
    if ($self->_group_has_workspace_role($group, $account)) {
        $gar->update( { role_id => $affiliate->role_id } );
    }
    else {
        $factory->Delete($gar);
    }
}

sub _group_has_workspace_role {
    my $self    = shift;
    my $group   = shift;
    my $account = shift;

    my $ws_count = sql_singlevalue(q{
        SELECT COUNT("Workspace".workspace_id)
          FROM "Workspace"
          JOIN group_workspace_role USING (workspace_id)
         WHERE group_workspace_role.group_id = ?
           AND "Workspace".account_id = ?
    }, $group->group_id, $account->account_id);

    return ( $ws_count ) ? 1 : 0;
}

1;
