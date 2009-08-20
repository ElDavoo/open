package Socialtext::GroupAccountRole;
# @COPYRIGHT@
use Moose;
use Socialtext::Moose::SqlTable;
use namespace::clean -except => 'meta';

with qw(
    Socialtext::Moose::Has::RoleId
    Socialtext::Moose::Has::AccountId
    Socialtext::Moose::Has::GroupId
);

has_table 'group_account_role';

sub update {
    my ($self, $proto_gar) = @_;
    require Socialtext::GroupAccountRoleFactory;
    Socialtext::GroupAccountRoleFactory->Update($self, $proto_gar);
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
