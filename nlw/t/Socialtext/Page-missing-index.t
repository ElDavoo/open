#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 4;

fixtures(qw( db ));

###############################################################################
# TEST: Make sure that "all_ids_newest_first()" doesn't issue a warning if the
# 'index.txt' file is missing for a page.
no_warnings_on_all_ids_newest_first: {
    # Create a dummy page to work with.
    my $hub  = create_test_hub();
    my $ws   = $hub->current_workspace();
    my $page = Socialtext::Page->new(hub => $hub)->create(
        title   => 'Eraseme',
        content => 'Please, erase me',
        creator => $hub->current_user,
    );

    isa_ok $page, 'Socialtext::Page', 'Created page to remove';

    # Make sure its got a file on disk
    my $file = File::Spec->catfile(
        Socialtext::Paths::page_data_directory( $ws->name ),
        'eraseme',
        'index.txt',
    );
    ok -f $file, '... which has an index.txt file on disk';

    # Remove the file
    my $rc = unlink $file;
    ok $rc, '... unlinked the file';

    # Make sure we issue no warnings
    my $warnings = '';
    local $SIG{__WARN__} = sub { $warnings .= $_ for @_ };

    my @ids = $hub->pages->all_ids_newest_first();
    is( $warnings, '', '... no warnings from calling all_ids_newest_first()' );
}
