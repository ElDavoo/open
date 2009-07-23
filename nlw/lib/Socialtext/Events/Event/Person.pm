package Socialtext::Events::Event::Person;
# @COPYRIGHT@
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use namespace::clean -except => 'meta';

extends 'Socialtext::Events::Event';
with 'Socialtext::Events::Event::HasPerson';

enum 'PersonEventAction' => qw(
    edit_save
    tag_add
    tag_delete
    view
    watch_add
    watch_delete
);

has '+action' => (isa => 'PersonEventAction');

after 'build_hash' => sub {
    my $self = shift;
    my $h = shift;
    $h->{event_class} = 'person';
};

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

Socialtext::Events::Event::Person - Person Event object.

=head1 DESCRIPTION

A Socialtext People C<Socialtext::Events::Event>. Adds restrictions to the
C<action> attribute.

Does C<Socialtext::Events::Event::HasPerson>.

=head1 SYNOPSIS

    my $person_ev = $source->next(); # See Socialtext::Events::Source
    my $user = $person_ev->person;

