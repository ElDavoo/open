#!perl
# @COPYRIGHT@
use warnings;
use strict;

use Test::Socialtext tests => 3;
fixtures(qw( admin_no_pages ));

BEGIN {
    use_ok( "Socialtext::Search::Solr::Factory" );
}

my $indexer = Socialtext::Search::Solr::Factory->create_indexer( 'admin' );
isa_ok( $indexer, 'Socialtext::Search::Solr::Indexer', "I HAS A FLAVOR!" );

my $searcher = Socialtext::Search::Solr::Factory->create_searcher( 'admin' );
isa_ok( $searcher, 'Socialtext::Search::Solr::Searcher', "I TOO HAS A FLAVOR!" );
