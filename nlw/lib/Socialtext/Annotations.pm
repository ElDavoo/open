package Socialtext::Annotations;

use Moose::Role;

has annotations => (is => 'rw', isa => 'Maybe[ArrayRef]', lazy_build => 1);
has annotation_triplets => (is => 'rw', isa => 'ArrayRef', lazy_build => 1);

sub _build_annotation_triplets {
    my $self = shift;

    warn "Building triplets";
    my $annos = $self->annotations;
    my @triplets;
    for my $anno (@$annos) {
        for my $namespace (keys %$anno) {
            while (my ($key, $val) = each %{ $anno->{$namespace} }) {
                push @triplets, [$namespace => $key => $val];
            }
        }
    }
    return \@triplets;
}

1;

