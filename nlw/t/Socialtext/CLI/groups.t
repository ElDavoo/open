#!perl
# @COPYRIGHT@
use warnings;
use strict;
use Test::Socialtext tests => 12;
use Test::Exception;
BEGIN { use_ok 'Socialtext::CLI'; }
use t::Socialtext::CLITestUtils qw/is_last_exit/;
use Test::Output qw(combined_from);

fixtures('db');

my $aa = create_test_account("Account AAA $^T");
my $ab = create_test_account("Account BBB $^T");

my ($ga, $gb);
lives_ok { $ga = create_test_group(account => $ab, unique_id => 'Group A') };
my $ga_id = $ga->group_id;
lives_ok { $gb = create_test_group(account => $aa, unique_id => 'Group B') };
my $gb_id = $gb->group_id;
$ga->add_user(user => create_test_user());

list_all: {

    my $output = combined_from { eval { new_cli()->list_groups() } };
    is_last_exit(0);
    #diag $output;
    my @lines = split("\n",$output);
    is scalar(@lines), 5, "correct line count";
    my $hdr = join (' | ',
        'ID', 'Group Name', '# of Workspaces', '# of Users', 'Primary Account',
        'Created', 'Created By');
    is $lines[2], "| $hdr |", "correct header";
    like $lines[3], qr/^\| $ga_id \| Group A /, "first row is group a";
    like $lines[4], qr/^\| $gb_id \| Group B /, "second row is group b";
}

list_account: {
    my $output = combined_from { eval {
        new_cli('--account' => "Account AAA $^T")->list_groups()
    } };
    is_last_exit(0);
    #diag $output;
    my @lines = split("\n",$output);
    is scalar(@lines), 4, "only one group in account a";
    my $hdr = join (' | ',
        'ID', 'Group Name', '# of Workspaces', '# of Users', 'Primary Account',
        'Created', 'Created By');
    is $lines[2], "| $hdr |", "correct header";
    like $lines[3], qr/^\| $gb_id \| Group B /, "first row is group b";
}

sub new_cli { return Socialtext::CLI->new(argv => \@_) }

