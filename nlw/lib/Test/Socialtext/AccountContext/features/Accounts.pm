package Test::Socialtext::AccountContext::features::Accounts;
# @COPYRIGHT@
use Moose;
use Test::More;
use namespace::clean -except => 'meta';

with 'Test::Socialtext::AccountContext::features';

sub Tests { 4 }

sub prepare {
    my $self = shift;
    Socialtext::Account->create(name=>$self->context->export_name);

    my $export = $self->_validate();
    my $other  = Socialtext::Account->create(name=>'Other Account');

    isa_ok $other, 'Socialtext::Account', 'other account is created';

    return +{
        export => $export,
        other  => $other,
    };
}

sub validate {
    my $self = shift;

    my $other = Socialtext::Account->new(name=>'Other Account');
    ok !$other, 'other account was not imported';

    my $export = $self->_validate();

    return +{
        export => $export,
        other  => $other,
    };
}

sub _validate {
    my $self = shift;
    my $export = Socialtext::Account->new(name=>$self->context->export_name);
    isa_ok $export, 'Socialtext::Account', 'account export exists';

    return $export;
}

__PACKAGE__->meta->make_immutable();
1;
