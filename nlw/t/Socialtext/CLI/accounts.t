#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 6;
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
