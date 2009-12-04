package Socialtext::Pluggable::Plugin::AccountMembership;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Pluggable::Plugin';
use Class::Field qw(const);
use Socialtext::Log qw/st_log/;

# TEMPORARY
use Socialtext::Role;
use Socialtext::SQL::Builder qw/sql_insert/;
use Socialtext::SQL qw/sql_singlevalue sql_execute/;

const hidden => 1;

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
    my $role    = shift;

    if ($account->user_set->object_directly_connected($user)) {
        $account->add_to_all_users_workspace(object => $user);
    }
}

sub remove_user_account_role {
    my $self    = shift;
    my $account = shift;
    my $user    = shift;
    my $role    = shift;

    # no-op
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
    my $role    = shift;

    if ($account->user_set->object_directly_connected($group)) {
        $account->add_to_all_users_workspace(object => $group);
    }
}

sub remove_group_account_role {
    my $self    = shift;
    my $account = shift;
    my $group   = shift;
    my $role    = shift;

    # no-op
}

1;
