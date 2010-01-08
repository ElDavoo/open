#!perl
# @COPYRIGHT@
use warnings;
use strict;

use Test::Socialtext tests => 5;
fixtures(qw( empty ));

BEGIN {
    use_ok( "Socialtext::Search::KinoSearch::Factory" );
}

my $indexer = Socialtext::Search::KinoSearch::Factory->create_indexer( 'empty' );
isa_ok( $indexer, 'Socialtext::Search::KinoSearch::Indexer', "I HAS A FLAVOR!" );

my $not_indexer = Socialtext::Search::KinoSearch::Factory->create_indexer( 'empty', config_type => 'notarealconfigtype' );
is( $not_indexer, undef, "I shouldn't work." );

my $searcher = Socialtext::Search::KinoSearch::Factory->create_searcher( 'empty' );
isa_ok( $searcher, 'Socialtext::Search::KinoSearch::Searcher', "I TOO HAS A FLAVOR!" );

my $not_searcher = Socialtext::Search::KinoSearch::Factory->create_searcher( 'empty', config_type => 'yourmama' );
is( $not_searcher, undef, "I shouldn't work either." );

