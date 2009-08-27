#!perl
# @COPYRIGHT@
use strict;
use warnings;

BEGIN {
    $ENV{NLW_APPCONFIG} = 'search_factory_class=Socialtext::Search::Solr::Factory';
}

use Test::Socialtext;
use Test::Socialtext::Search;
use Socialtext::Search::Config;

fixtures(qw( admin no-ceq-jobs ));

plan tests => 19;

my $hub            = Test::Socialtext::Search::hub();

# make an index and confirm it works
index_exists();

# remove the index
index_removed();

# makes sure things still work when we try again
index_exists();
exit;

sub index_exists {
    create_and_confirm_page(
        'a test page',
        "a simple page containing a funkity string"
    );
    search_for_term('funkity');
}

sub index_removed {
    Socialtext::Search::Solr::Factory->create_indexer(
        $hub->current_workspace->name )->delete_workspace();

    search_for_term('funkity', 1);
}
