package Test::Socialtext::Account;
# @COPYRIGHT@
use strict;
use warnings;
use Exporter;
use Socialtext::CLI;
use File::Temp qw(tempdir);
use Test::Socialtext::CLIUtils qw(expect_success);

our @EXPORT_OK = qw/delete_recklessly import_account_ok export_account/;

sub delete_recklessly {
    my ($class, $account) = @_;

    # Load classes on demand
    require Socialtext::SQL;
    require Socialtext::Account;

    # Null out parent_ids in gadgets referencing this account's gadgets
    Socialtext::SQL::sql_execute(q{
        UPDATE gadget_instance
           SET parent_instance_id = NULL
         WHERE parent_instance_id IN (
            SELECT gadget_instance_id
              FROM gadget_instance
             WHERE container_id IN (
                SELECT container_id
                  FROM container
                 WHERE user_set_id = ?
             )
         )
    }, $account->user_set_id);

    Socialtext::SQL::disconnect_dbh();

    $account->delete;
}

sub export_account {
    my $account = shift;

    my $export_base = tempdir(CLEANUP => 1);
    my $export_dir   = File::Spec->catdir($export_base, 'account');

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [
                    '--account' => $account->name,
                    '--dir'     => $export_dir,
                ],
            )->export_account();
        },
        qr/account exported to/,
        'Account exported',
    );

    return $export_dir;
}

sub import_account_ok {
    my $export_dir = shift;
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => ['--dir' => $export_dir],
            )->import_account();
        },
        qr/account imported/,
        '... Account re-imported',
    );
}

1;
