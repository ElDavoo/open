package Socialtext::Annotations;

use Moose::Role;
use Socialtext::JSON qw/encode_json decode_json_utf8/;

has anno_blob => (is => 'rw', isa => 'Str', lazy_build => 1);

before 'anno_blob' => sub {
    my $self = shift;

    $self->_check_annotations(@_) if (@_);
};

sub annotations {
    my $self = shift;
    my $anno_blob = $self->anno_blob;
    return unless $anno_blob;
    return decode_json_utf8($anno_blob);
}

sub annotation_triplets {
    my $self = shift;

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

sub _check_annotations {
    my $self = shift;
    my $anno_string = shift;
    my $max_length = shift;

    return unless defined $anno_string;

    my $annos = decode_json_utf8($anno_string);
    die "Annotation must be an array\n" unless ref($annos) eq 'ARRAY';
    for my $anno (@$annos) {
        while (my ($type, $keyvals) = each %$anno) {
            die "Annotation type cannot contain '|' character\n"
                if $type =~ m/\|/;
            die "Annotation types must hold HASHes\n"
                unless ref($keyvals) eq 'HASH';
            my @keys = keys %$keyvals;
            for my $key (@keys) {
                die "Annotation key cannot contain '|' character\n"
                    if $key =~ m/\|/;
                my $val = $anno->{$type}{$key};
                die "Annotation value must be a Scalar - (is: "
                    . ref($val) . ")\n" if ref($val);
            }
        }
    }

    if ($max_length) {
        my $len = length($anno_string);
        die "Annotation must be <= " . $max_length . " in size (is: $len)\n"
           if $len > $max_length;
    }
}
1;

