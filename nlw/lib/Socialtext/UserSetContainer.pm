package Socialtext::UserSetContainer;
use Moose::Role;
use Socialtext::UserSet;
use namespace::autoclean -except => 'meta';

requires 'user_set_id';

has 'user_set' => (
    is => 'ro', isa => 'Socialtext::UserSet',
    lazy_build => 1,
);

sub _build_user_set {
    my $self = shift;
    return Socialtext::UserSet->new(
        owner => $self,
        owner_id => $self->user_set_id,
    );
}

1;
__END__

=head1 NAME

Socialtext::UserSetContainer - Role for things containing UserSets

=head1 SYNOPSIS

  package MyContainer;
  use Moose;
  has 'user_set_id' => (..., isa => 'Int');
  with 'Socialtext::UserSetContainer';

  my $o = MyContainer->new(); # or w/e
  my $uset = $o->user_set;

=head1 DESCRIPTION

Adds a C<user_set> attribute to your class that automatically constructs the 
L<Socialtext::UserSet> object for this container.

Requires that the base class has a C<user_set_id> accessor.

Instances maintain a weak reference to the owning object.

=cut
