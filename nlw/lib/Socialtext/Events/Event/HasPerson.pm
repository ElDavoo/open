package Socialtext::Events::Event::HasPerson;
# @COPYRIGHT@
use Moose::Role;
use namespace::clean -except => 'meta';

has 'person_id' => (is => 'ro', isa => 'Int');
has 'person' => (is => 'ro', isa => 'Maybe[Socialtext::User]', lazy_build => 1);

sub _build_person { Socialtext::User->new(user_id => $_[0]->person_id) }

requires 'add_user_to_hash';
after 'build_hash' => sub {
    my $self = shift;
    my $hash = shift;

    if ($self->person_id && $self->person) {
        $hash->{person} ||= {};
        $self->add_user_to_hash('person' => $self->person, $hash);
    }
};

1;
__END__

=head1 NAME

Socialtext::Events::Event::HasPerson - Role to add a person field.

=head1 DESCRIPTION

Adds C<person> and C<person_id> attributes.  The C<person> was the "object" of
an event; he/she is the user that the action was done to (e.g. he/she was
tagged).  The C<actor> is the user who did the action.

Will add the person user to the hash during C<build_hash()>.

=head1 SYNOPSIS

    package MyEvent;
    use Moose;
    with 'Socialtext::Events::Event::HasPerson';

=head1 SEE ALSO

C<Socialtext::Events::Event::Person> - a concrete class that uses this role.
