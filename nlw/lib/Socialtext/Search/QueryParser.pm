package Socialtext::Search::QueryParser;
# @COPYRIGHT@
use Moose;
use namespace::clean -except => 'meta';

=head1 NAME

Socialtext::Search::QueryParser

=head1 SYNOPSIS

  my $qp = Socialtext::Search::QueryParser->new;
  my $query = $qp->parse($query_string);

=head1 DESCRIPTION

Base class for parsing search queries.

=cut

has 'searchable_fields' => (is => 'ro', isa => 'ArrayRef[Str]', lazy_build => 1);

sub parse {
    my $self = shift;
    my $query_string = shift;

    # Fix the raw query string.  Mostly manipulating "field:"-like strings.
    $query_string = $self->munge_raw_query_string($query_string);

    return $query_string;
}

# Raw text manipulations like this are not 100% safe to do, but should be okay
# considering their esoteric nature (i.e. dealing w/ fields).
sub munge_raw_query_string {
    my ( $self, $query ) = @_;

    # Establish some field synonyms.
    $query =~ s/=/title:/g;        # Old style title search
    $query =~ s/category:/tag:/gi; # Old name for tags
    $query =~ s/tag:\s*/tag:/gi;   # fix capitalization and allow an extra space

    # Find everything that looks like a field, but is not.  I.e. in "cow:foo"
    # we would find "cow:". 
    my $field_map;
    my @non_fields;
    while ( $query =~ /(\w+):/g ) {
        my $maybe_field = $1;
        $field_map ||= { map { $_ => 1 } @{ $self->searchable_fields } };
        push @non_fields, $maybe_field unless $field_map->{$maybe_field};
    }

    # If it looks like a field but is not then remove the ":".  This prevents
    # things being treated as fields when they are not fields.
    for my $non_field (@non_fields) {
        $non_field = quotemeta $non_field;
        $query =~ s/(${non_field}):/$1 /g;
    }

    return $query;
}


__PACKAGE__->meta->make_immutable;
1;
