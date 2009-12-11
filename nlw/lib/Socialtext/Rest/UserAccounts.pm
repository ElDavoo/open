package Socialtext::Rest::UserAccounts;
# @COPYRIGHT@
use Moose;
use Socialtext::User;
use Socialtext::HTTP qw(:codes);
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest::Collection';

# We punt to the permission handling stuff below.
sub permission { +{ GET => undef } }

sub authorized_to_view {
    my ($self, $user) = @_;
    my $acting_user = $self->rest->user;
    return $user;
}

override get_resource => sub {
    my $self = shift;
    my $rest   = $self->rest;
    my $viewer = $rest->user;

    my $user = eval { Socialtext::User->Resolve($self->username) };
    die Socialtext::Exception::NotFound->new() unless $user;

    unless ($viewer) {
        $rest->header( -status => HTTP_401_Unauthorized );
        return ();
    }
    if (!$viewer->is_business_admin and $viewer->user_id != $user->user_id) {
        $rest->header( -status => HTTP_401_Unauthorized );
        return ();

    }

    my @accounts;
    my %account_ids;

    my $user_accounts = $user->accounts;
    my $pri_acct = $user->primary_account_id;
    for my $acct (@$user_accounts) {
        my $acct_id = $acct->account_id;
        my $acct_hash = {
            account_id => $acct_id,
            account_name => $acct->name,
            is_primary => ($acct_id == $pri_acct ? 1 : 0),
        };
        push @accounts, $acct_hash;
        $account_ids{$acct_id} = $acct_hash;
    }

    my $user_wksps = $user->workspaces;
    while (my $wksp = $user_wksps->next) {
        my $acct_id = $wksp->account_id;
        my $wksp_hash = {
            name => $wksp->name,
            workspace_id => $wksp->workspace_id,
        };

        my $acct_hash = $account_ids{$acct_id};
        push @{ $acct_hash->{via_workspace} }, $wksp_hash;
    }

    eval { 
    my $user_groups = $user->groups;
    while (my $grp = $user_groups->next) {
        my $group_hash = {
            name => $grp->driver_group_name,
            group_id => $grp->group_id,
        };
        my $grp_accts = $grp->accounts;
        while (my $acct = $grp_accts->next) {
            my $acct_id = $acct->account_id;

            my $acct_hash = $account_ids{$acct_id};
            push @{ $acct_hash->{via_group} }, $group_hash;
        }
    }
    };
    if ($@) {
        warn "ERROR: $@";
    }

    my $limit = $rest->query->param('limit') || 20;
    my $offset = $rest->query->param('offset') || 0;
    my $order = $rest->query->param('order') || 'account_id';
    my $reverse = $rest->query->param('reverse');
    my $startIndex = $offset + 1;
    my $total = @accounts;
    if ($reverse) {
        @accounts = $order eq 'account_id'
            ? sort { $b->{$order} <=> $a->{$order} } @accounts
            : sort { $b->{$order} cmp $a->{$order} } @accounts;
    }
    else {
        @accounts = $order eq 'account_id'
            ? sort { $a->{$order} <=> $b->{$order} } @accounts
            : sort { $a->{$order} cmp $b->{$order} } @accounts;
    }
    @accounts = splice @accounts, $offset, $limit;
    return {
        startIndex => "$startIndex",
        itemsPerPage => "$limit",
        totalResults => "$total",
        entry => \@accounts,
    };
};

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 NAME

Socialtext::Rest::UserAccounts - List the accounts a user belongs to & why

=head1 SYNOPSIS

    GET /data/users/:username/accounts

=head1 DESCRIPTION

View the list of accounts a user is a member of.  Caller can only see groups
they created or are also a member of.  Business admins can see all groups.

=cut
