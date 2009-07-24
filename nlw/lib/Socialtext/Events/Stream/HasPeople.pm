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
    my $sources = $self->$code() || [];

    my $ids = $self->people_account_ids;
    return $sources unless $ids && @$ids;

    push @$sources, $self->construct_source(
        'Socialtext::Events::Source::PersonVisible',
        visible_account_ids => $ids,
    );

    return $sources;
};

1;

__END__

=head1 NAME

Socialtext::Events::Stream::HasPeople - Stream role to add standard person
events.

=head1 DESCRIPTION

Adds Socialtext People ("person") events to a Stream.

Since this class is a Stream role, it can be mixed-in to a Stream class at
run-time.

=head1 SYNOPSIS

To construct a Stream of just person events:

    my $stream = Socialtext::Events::Stream->new_with_traits(
        traits => ['HasPeople'], # literally
        viewer => $current_user,
        offset => 0,
        limit => 50,
    );

