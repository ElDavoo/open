package Socialtext::Rest::Pageable;
# @COPYRIGHT@
use Moose::Role;

use constant max_per_page => 100;

requires qw(_get_total_results _get_entities);

has 'pageable' => ( is => 'ro', isa => 'Bool', lazy_build => 1 );
sub _build_pageable {
    my $self = shift;
    defined $self->rest->query->param('startIndex');
}

has 'start_index' => ( is => 'ro', isa => 'Int', lazy_build => 1 );
sub _build_start_index {
    my $self = shift;
    my $index = $self->rest->query->param('startIndex');
    return defined $index ? $index : $self->rest->query->param('offset') || 0;
}

has 'items_per_page' => ( is => 'ro', isa => 'Int', lazy_build => 1 );
sub _build_items_per_page {
    my $self = shift;
    my $count = $self->rest->query->param('count') || return 25;
    return $count > max_per_page ? max_per_page : $count;
}

has 'reverse' => ( is => 'ro', isa => 'Bool', lazy_build => 1 );
sub _build_reverse {
    my $self = shift;
    $self->rest->query->param('reverse');
}

has 'order' => ( is => 'ro', isa => 'Maybe[Str]', lazy_build => 1 );
sub _build_order {
    my $self = shift;
    $self->rest->query->param('order');
}

sub get_resource {
    my ($self, $rest, $content_type) = @_;

    Socialtext::Timer->Continue('_get_entities');
    my $results = $self->_get_entities($rest);
    Socialtext::Timer->Pause('_get_entities');

    Socialtext::Timer->Continue('_entity_hash_map');
    @$results = map { $self->_entity_hash($_) } @$results;
    Socialtext::Timer->Pause('_entity_hash_map');

    if ($self->pageable and $content_type eq 'application/json') {
        return {
            startIndex => $self->start_index+0,
            itemsPerPage => $self->items_per_page+0,
            totalResults => $self->_get_total_results()+0,
            entry => $results,
        }
    }
    else {
        return $results;
    }
};

sub _entity_hash {
    my ($self, $item) = @_;
    return $item;
}

=head1 NAME

Socialtext::Rest::Pageable - TBD

=head1 SYNOPSIS

TBD

=head1 DESCRIPTION

TBD

=cut


1;
