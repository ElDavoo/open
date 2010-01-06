#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 12;
use Socialtext::CLI;
use Test::Socialtext::Account;
use Test::Output qw(combined_from);
use Test::Socialtext::CLIUtils qw(expect_success);
use File::Temp qw(tempdir);
use File::Path qw(rmtree);
use YAML qw(LoadFile DumpFile);

###############################################################################
# Fixtures: db
fixtures(qw( db ));

###############################################################################
# TEST: Unversioned export
unversioned: {
    my $account = create_test_account_bypassing_factory();
    my $results = export_and_import_results(
        account => $account,
        flush   => sub {
            Test::Socialtext::Account->delete_recklessly($account);
        },
        mangle  => sub {
            my $acct_data = shift;
            delete $acct_data->{version};
        }
    );
    like $results, qr/account imported/, '... import ok when unversioned';
}

###############################################################################
# TEST: Export and re-import at same version level.
version_match: {
    my $account = create_test_account_bypassing_factory();
    my $results = export_and_import_results(
        account => $account,
        flush   => sub {
            Test::Socialtext::Account->delete_recklessly($account);
        },
    );
    like $results, qr/account imported/, '... import ok at same version';
}

###############################################################################
# TEST: Export w/lower version number; imports ok.
version_lower: {
    my $account = create_test_account_bypassing_factory();
    my $results = export_and_import_results(
        account => $account,
        flush   => sub {
            Test::Socialtext::Account->delete_recklessly($account);
        },
        mangle  => sub {
            my $acct_data = shift;
            $acct_data->{version}--;
        },
    );
    like $results, qr/account imported/, '... import ok at lower version';
}

###############################################################################
# TEST: Export w/higher version number; fails.
version_higher: {
    my $account = create_test_account_bypassing_factory();
    my $results = export_and_import_results(
        account => $account,
        flush   => sub {
            Test::Socialtext::Account->delete_recklessly($account);
        },
        mangle  => sub {
            my $acct_data = shift;
            $acct_data->{version}++;
        },
    );
    like $results, qr/Cannot import an Account with a version greater/,
        '... import FAILED at higher version';
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
