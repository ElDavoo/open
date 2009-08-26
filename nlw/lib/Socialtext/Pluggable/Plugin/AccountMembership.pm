package Socialtext::Pluggable::Plugin::AccountMembership;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Pluggable::Plugin';
use Socialtext::Log qw/st_log/;
use Socialtext::UserAccountRoleFactory;

# TEMPORARY
use Socialtext::Role;
use Socialtext::SQL::Builder qw/sql_insert/;
use Socialtext::SQL qw/sql_singlevalue sql_execute/;

sub register {
    my $class = shift;

    $class->add_hook('nlw.add_user_account_role'
        => 'add_user_account_role');

    $class->add_hook('nlw.remove_user_account_role'
        => 'remove_user_account_role');
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

    # Sometimes we're passed a proper user object, sometimes it's a metadata
    # object. Handle both cases here.
    my $primary_account_id = ( $user->can('primary_account_id') )
        ? $user->primary_account_id
        : $user->{primary_account_id};

    # exit if the user still has a role in the account, or if its the primary
    # account.
    return if $self->_has_role($user, $account)
        || $primary_account_id == $account->account_id;

    $factory->Delete($uar);
}

sub _has_role {
    my $self    = shift;
    my $user    = shift;
    my $account = shift;

    my $ws_count = sql_singlevalue(q{
        SELECT COUNT("Workspace".workspace_id)
          FROM "Workspace"
          JOIN "UserWorkspaceRole" USING (workspace_id)
         WHERE "UserWorkspaceRole".user_id = ?
           AND "Workspace".account_id = ?
    }, $user->user_id, $account->account_id);

    return ( $ws_count ) ? 1 : 0;
}

1;
