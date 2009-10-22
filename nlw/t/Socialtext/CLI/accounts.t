#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Cwd;
use File::Path qw(rmtree);
use File::Spec;
use File::Temp qw(tempdir);
use Test::Socialtext tests => 16;
use Socialtext::CLI;
use Socialtext::SQL qw(:exec);
use t::Socialtext::CLITestUtils qw(expect_success expect_failure);

###############################################################################
# Fixtures: db
fixtures(qw( db ));

###############################################################################
# TEST: List Accounts, by name
list_accounts_by_name: {
    my $sql      = q{SELECT name FROM "Account" ORDER BY name};
    my $sth      = sql_execute($sql);
    my @accounts = map { $_->[0] } @{ $sth->fetchall_arrayref };

    expect_success(
        sub {
            Socialtext::CLI->new()->list_accounts();
        },
        (join '', map { "$_\n" } @accounts),
        'list-accounts by name',
    );
}

###############################################################################
# TEST: List Accounts, by id (although its still ordered by name)
list_accounts_by_id: {
    my $sql      = q{SELECT account_id FROM "Account" ORDER BY name};
    my $sth      = sql_execute($sql);
    my @accounts = map { $_->[0] } @{ $sth->fetchall_arrayref };

    expect_success(
        sub {
            Socialtext::CLI->new( argv => ['--ids'] )->list_accounts();
        },
        (join '', map { "$_\n" } @accounts),
        'list-accounts by id',
    );

}

###############################################################################
# TEST: Exporting a non-existent Account
export_non_existent_account: {
    my $bogus_account = 'no-existy';
    expect_failure(
        sub {
            Socialtext::CLI->new(
                argv => ['--account', $bogus_account],
            )->export_account();
        },
        qr/There is no account named "$bogus_account"/,
        'Exporting invalid account fails',
    );
}

###############################################################################
# TEST: Export an Account
export_account: {
    my $account   = create_test_account_bypassing_factory();
    my $acct_name = $account->name();

    # custom export root
    my $export_root = Cwd::abs_path(tempdir());
    local $ENV{ST_EXPORT_DIR} = $export_root;

    # export the Account
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => ['--account', $acct_name],
            )->export_account();
        },
        qr/$acct_name account exported to/,
        'Exported valid account',
    );

    # export directory should exist, and contain "accounts.yaml" file.
    my $export_dir = File::Spec->catdir(
        $export_root,
        "${acct_name}.id-" . $account->account_id . ".export"
    );
    ok -e $export_dir, '... export directory exists';
    ok -f "$export_dir/account.yaml", '... account.yaml file exists';

    # CLEANUP
    rmtree [$export_root], 0;
}

###############################################################################
# TEST: Import an Account
import_account: {
    my $account   = create_test_account_bypassing_factory();
    my $acct_name = $account->name();

    # custom export root
    my $export_root = Cwd::abs_path(tempdir());
    local $ENV{ST_EXPORT_DIR} = $export_root;

    # export the Account
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => ['--account', $acct_name],
            )->export_account();
        },
        qr/$acct_name account exported to/,
        'Exported valid account',
    );

    # Calculate where the Account got exported to
    my $export_dir = File::Spec->catdir(
        $export_root,
        "${acct_name}.id-" . $account->account_id . ".export"
    );

    # re-import the Account, under a new name
    my $new_name = 'Fred';
    my $imported = Socialtext::Account->new(name => $new_name);
    ok !$imported, "... target Account doesn't exist yet";

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => ['--dir', $export_dir, '--name', $new_name],
            )->import_account();
        },
        qr/$new_name account imported/,
        '... Account imported',
    );

    $imported = Socialtext::Account->new(name => $new_name);
    ok $imported, '... import was successful';
}
