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

    unless ($viewer) {
        $rest->header( -status => HTTP_401_Unauthorized );
        return ();
    }

    my $user = eval { Socialtext::User->Resolve($self->username) };
    die Socialtext::Exception::NotFound->new() unless $user;

    my @accounts;
    my %account_ids;

    my $user_accounts = $user->accounts;
    for my $acct (@$user_accounts) {
        my $acct_id = $acct->account_id;
        
        my $uar = $acct->role_for_user(user => $user);
        my $acct_hash = {
            account_id => $acct_id,
            account_name => $acct->name,
            ($uar->name eq 'member' ? 
                (is_primary => ($user->primary_account_id == $acct_id ? 1 : 0))
                : ()),
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

        if (my $acct_hash = $account_ids{$acct_id}) {
            push @{ $acct_hash->{via_workspace} }, $wksp_hash;
        }
        else {
            my $acct = $wksp->account;
            my $acct_hash = {
                account_id => $acct_id,
                account_name => $acct->name,
                via_workspace => [$wksp_hash],
            };
            push @accounts, $acct_hash;
            $account_ids{$acct_id} = $acct_hash;
        }
    }

    eval { 
    my $user_groups = $user->groups;
    while (my $grp = $user_groups->next) {
        my $acct_id = $grp->primary_account_id;
        warn "Looking at group: " . $grp->driver_group_name;
        my $group_hash = {
            name => $grp->driver_group_name,
            group_id => $grp->group_id,
        };

        if (my $acct_hash = $account_ids{$acct_id}) {
            push @{ $acct_hash->{via_group} }, $group_hash;
        }
        else {
            my $acct = $grp->primary_account;
            my $acct_hash = {
                account_id => $acct_id,
                account_name => $acct->name,
                via_group => [$group_hash],
            };
            push @accounts, $acct_hash;
            $account_ids{$acct_id} = $acct_hash;
        }
    }
    };
    if ($@) {
        warn "ERROR: $@";
    }


    return {
        startIndex => 1,
        itemsPerPage => 20,
        totalResults => scalar(@accounts),
        entry => \@accounts,
    };
};

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 NAME

Socialtext::Rest::UserSharedGroups - List the groups a user belongs to

=head1 SYNOPSIS

    GET /data/users/:username/groups

=head1 DESCRIPTION

View the list of groups a user is a member of, or has created.  Caller
can only see groups they created or are also a member of.  Business admins
can see all groups.

=cut
