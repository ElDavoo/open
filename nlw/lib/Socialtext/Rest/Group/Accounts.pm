package Socialtext::Rest::Group::Accounts;
# @COPYRIGHT@
use Moose;
use Socialtext::Group;
use Socialtext::Permission qw/ST_READ_PERM/;
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest::Collection';

# Anybody can see these, since they are just the list of workspaces the user
# has 'selected'.
sub permission { +{} }

sub collection_name { 'Group accounts' }

sub _entities_for_query {
    my $self = shift;
    my $group_id = $self->group_id;
    my $user = $self->rest->user();

    my $group = Socialtext::Group->GetGroup(group_id => $group_id);
    die Socialtext::Exception::NotFound->new() unless $group;

    my $can_read = $group->user_can(
        user => $user,
        permission => ST_READ_PERM
    );
    die Socialtext::Exception::NotFound->new()
        unless $user->is_business_admin
            or $group->creator->user_id == $user->user_id
            or $can_read;

    return $group->accounts->all();
}

sub _entity_hash { 
    return $_[1]->to_hash;
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 NAME

Socialtext::Rest::Group::Accounts - List accounts a group is in

=head1 SYNOPSIS

    GET /data/groups/:group_id/accounts

=head1 DESCRIPTION

View the list of accounts the specified group is in.

=cut
