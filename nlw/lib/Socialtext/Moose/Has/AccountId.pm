package Socialtext::Moose::Has::AccountId;
# @COPYRIGHT@
use Moose::Role;
use Socialtext::Moose::SqlTable::Meta::Attribute::Trait::DbColumn;
use namespace::clean -except => 'meta';

has 'account_id' => (
    is => 'ro', isa => 'Int',
    required => 1,
    writer => '_account_id',
    trigger => \&_set_account_id,
    primary_key => 1,
    traits => [
        'Socialtext::Moose::SqlTable::Meta::Attribute::Trait::DbColumn'
    ],
);

has 'account' => (
    is => 'ro', isa => 'Socialtext::Account',
    lazy_build => 1,
);

sub _set_account_id {
    my $self = shift;
    $self->clear_account();
}

sub _build_account {
    my $self = shift;
    require Socialtext::Account;
    my $account_id = $self->account_id();
    my $account = Socialtext::Account->new( account_id => $account_id );
    unless ($account) {
        die "account_id=$account_id no longer exists";
    }
    return $account;
}

no Moose::Role;
1;
