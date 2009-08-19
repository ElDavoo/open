package Socialtext::UserAccountRole;
# @COPYRIGHT@
use Moose;
use Socialtext::Moose::SqlTable;
use namespace::clean -except => 'meta';

with qw(
    Socialtext::Moose::Has::RoleId
    Socialtext::Moose::Has::AccountId
    Socialtext::Moose::Has::UserId
);

has_table 'user_account_role';

sub update {
    my ($self, $proto_ugr) = @_;
    require Socialtext::UserAccountRoleFactory;
    Socialtext::UserAccountRoleFactory->Update($self, $proto_ugr);
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
