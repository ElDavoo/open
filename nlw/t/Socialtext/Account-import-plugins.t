#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 4;
use Socialtext::CLI;
use Test::Socialtext::Account;
use Test::Output qw(combined_from);
use t::Socialtext::CLITestUtils qw(expect_success);
use File::Temp qw(tempdir);
use File::Path qw(rmtree);
use YAML qw(LoadFile DumpFile);

###############################################################################
# Fixtures: db
fixtures(qw( db ));

###############################################################################
# TEST: Importing an Account onto a machine that's missing one of the Plugins
# that was enabled in the Account on export shouldn't be fatal; just skip the
# missing Plugin.
missing_plugin: {
    my $account = create_test_account_bypassing_factory();
    my $plugin  = 'nonexistent';
    my $results = export_and_import_results(
        account => $account,
        flush   => sub {
            Test::Socialtext::Account->delete_recklessly($account);
        },
        mangle  => sub {
            my $acct_data = shift;
            push @{$acct_data->{plugins}}, $plugin;
        }
    );
    like $results, qr/account imported/, '... import successful';
    like $results, qr/'$plugin' plugin missing; skipping/,
        '... skipping the missing plugin';
}


###############################################################################
# Helper routine to export an Account, and return the CLI output generated
# during the import.  Supports optional mangling of the exported YAML data.
sub export_and_import_results {
    my %args    = @_;
    my $account = $args{account};
    my $flush   = $args{flush}  || sub { };
    my $mangle  = $args{mangle} || sub { };

    my $export_base  = tempdir(CLEANUP => 1);
    my $export_dir   = File::Spec->catdir($export_base, 'account');
    my $account_yaml = File::Spec->catfile($export_dir, 'account.yaml');

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [
                    '--account', $account->name,
                    '--dir',     $export_dir,
                ],
            )->export_account();
        },
        qr/account exported to/,
        'Account exported',
    );

    # Flush our test data.
    $flush->();
    Socialtext::Cache->clear();

    # Mangle the exported Account's YAML file
    my $data = LoadFile($account_yaml);
    $mangle->($data);
    DumpFile($account_yaml, $data);

    # Re-import the Account.
    my $output = combined_from( sub {
        eval {
            Socialtext::CLI->new(
                argv => ['--dir', $export_dir],
            )->import_account();
        };
    } );

    # CLEANUP
    rmtree [$export_base], 0;

    # Return the results
    return $output;
}
