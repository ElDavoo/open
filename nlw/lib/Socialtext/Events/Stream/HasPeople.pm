package Socialtext::Events::Stream::HasPeople;
# @COPYRIGHT@
use Moose::Role;
use Socialtext::Events::Source::PersonVisible;
use namespace::clean -except => 'meta';

requires 'assemble';
requires '_build_sources';
requires 'account_ids_for_plugin';

has 'people_account_ids' => (
    is => 'rw', isa => 'ArrayRef[Int]',
    lazy_build => 1,
);

before 'assemble' => sub {
    my $self = shift;
    $self->people_account_ids; # force builder
    return;
};

sub _build_people_account_ids { $_[0]->account_ids_for_plugin('people'); }

around '_build_sources' => sub {
    my $code = shift;
    my $self = shift;
    my $sources = $self->$code;

    my $ids = $self->people_account_ids;
    return unless $ids && @$ids;
    push @$sources, $self->construct_source(
        'Socialtext::Events::Source::PersonVisible',
        visible_account_ids => $ids,
    );

    return $sources;
};

1;
