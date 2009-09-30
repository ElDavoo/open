package Socialtext::Rest::AccountGroups;
# @COPYRIGHT@
use Moose;
use Socialtext::Account;
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest::Collection';

sub permission { +{ GET => undef } }
sub collection_name { "Account Groups" }

sub _entities_for_query {
    my $self      = shift;
    my $rest      = $self->rest;
    my $user      = $rest->user;
    my $acct_name = $self->acct();
    my $account   = Socialtext::Account->new( name => $acct_name );
    return () unless $account;

    my @groups;
    my $group_cursor = $account->groups();
    if ($user->is_business_admin) {
        @groups = $group_cursor->all();
    }
    else {
        while (my $g = $group_cursor->next) {
            eval {
                if ($g->creator->user_id == $user->user_id 
                        or $g->has_user($user)) {
                    push @groups, $g;
                }
            };
            warn $@ if $@;
        }
    }

    return @groups;
}

sub _entity_hash {
    my $self  = shift;
    my $group = shift;

    return $group->to_hash( show_members => $self->{_show_members} );
}

around get_resource => sub {
    my $orig = shift;
    my $self = shift;

    $self->{_show_members} = $self->rest->query->param('show_members') ? 1 : 0;
    return $orig->($self, @_);
};

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
1;

=head1 NAME

Socialtext::Rest::AccountGroups - Groups in an account.

=head1 SYNOPSIS

    GET /data/accounts/:acct/groups

=head1 DESCRIPTION

Every Socialtext account has a collection of zero or more groups
associated with it. At the URI above, it is possible to view a list of those
groups.

=cut
