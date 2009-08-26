# @COPYRIGHT@
package Socialtext::Search::Solr::QueryParser;
use Moose;

extends 'Socialtext::Search::QueryParser';

sub _build_searchable_fields { [qw/key title tag text/] }

1;
