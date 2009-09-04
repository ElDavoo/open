# @COPYRIGHT@
package Socialtext::Search::Solr::QueryParser;
use Moose;

=head1 NAME

Socialtext::Search::Solr::QueryParser

=head1 SYNOPSIS

  my $qp = Socialtext::Search::QueryParser->new;
  my $query = $qp->parse($query_string);

=head1 DESCRIPTION

Pre-parse Solr specific query options.

=cut

extends 'Socialtext::Search::QueryParser';

sub _build_searchable_fields { [qw/title tag body/] }

around 'parse' => sub {
    my ( $orig, $self, $query_string ) = @_;

    $query_string = $orig->($self, $query_string);

    if ($query_string =~ m/\*/) {
        $query_string = "{!defType=lucene}$query_string";
    }
    return $query_string;
};

1;
