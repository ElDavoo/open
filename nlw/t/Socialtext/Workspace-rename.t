#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 12;
use Socialtext::EmailAlias;
use Socialtext::File;
use Socialtext::Paths;
use Socialtext::Account;
use Socialtext::Workspace;

# Fixtures: help
#
# - Need "help" WS in place so that default pages get copied in to new
#   Workspaces.
fixtures(qw( help ));

{
    my $ws = Socialtext::Workspace->create(
        name       => 'short-name',
        title      => 'Longer Title',
        account_id => Socialtext::Account->Socialtext()->account_id,
    );

    $ws->rename( name => 'new-name' );

    is( $ws->name(), 'new-name', 'workspace name is new-name' );

    for my $dir (
        Socialtext::Paths::plugin_directory('short-name'),
        Socialtext::Paths::user_directory('short-name'),
    ) {
        ok( ! -d $dir, "$dir does not exist after workspace is renamed" );
    }

    ok( ! Socialtext::EmailAlias::find_alias('short-name'),
        'short-name alias does not exist after rename' );

    for my $dir (
        Socialtext::Paths::plugin_directory('new-name'),
        Socialtext::Paths::user_directory('new-name'),
    ) {
        ok( -d $dir, "$dir exists after workspace is renamed" );
    }

    my $index = Socialtext::File::catfile( $page_dir, 'index.txt' );
    ok( -f readlink $index, 'index.txt symlink points to real file' );

    ok( Socialtext::EmailAlias::find_alias('new-name'),
        'new-name alias exists after rename' );
}
