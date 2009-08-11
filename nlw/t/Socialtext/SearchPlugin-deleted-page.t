#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 11;
use Test::Socialtext::Search;
fixtures( 'no-ceq-jobs', 'admin' );

{
    my $title = 'A Page with a Wacktastic Title';
    create_and_confirm_page(
        $title,
        'totally irrelevant'
    );
    search_for_term('wacktastic');

    delete_page($title);

    search_for_term( 'wacktastic', 'should not be found' );
}
