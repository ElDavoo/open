#!perl
# @COPYRIGHT@
use warnings;
use strict;
use Test::Socialtext tests => 39;
use Test::Exception;
BEGIN { use_ok 'Socialtext::CLI'; }
use Test::Socialtext::CLIUtils qw/is_last_exit/;
use Test::Output qw(combined_from);

fixtures('db');

my $aa = create_test_account_bypassing_factory("Account AAA $^T");
my $ab = create_test_account_bypassing_factory("Account BBB $^T");
my $header = qr/\|\s+ID\s+\|\s+Group Name\s+\|\s+# Wksps\s+\|\s+# Users\s+\|\s+Primary Account\s+\|\s+Created\s+\|\s+Created By\s+\|/;
################################################################################
no_groups: {
    my $output = combined_from { eval { new_cli()->list_groups() } };
    is_last_exit(1);
    like $output, qr/No Groups found/i, "no groups found";
}

my ($ga, $gb);
lives_ok { $ga = create_test_group(account => $ab, unique_id => 'Group A') };
my $ga_id = $ga->group_id;
lives_ok { $gb = create_test_group(account => $aa, unique_id => 'Group B') };
my $gb_id = $gb->group_id;
$ga->add_user(user => create_test_user());

################################################################################
list_all: {

    my $output = combined_from { eval { new_cli()->list_groups() } };
    is_last_exit(0);
    #diag $output;
    my @lines = split("\n",$output);

    is scalar(@lines), 5, "correct line count";
    like $lines[2], $header, "correct header";
    like $lines[3], qr/^\|\s+$ga_id\s+\|\s+Group A\s+/, "first row is group a";
    like $lines[4], qr/^\|\s+$gb_id\s+\|\s+Group B\s+/, "second row is group b";
}

################################################################################
list_account: {
    my $output = combined_from { eval {
        new_cli('--account' => "Account AAA $^T")->list_groups()
    } };
    is_last_exit(0);
    #diag $output;
    my @lines = split("\n",$output);

    is scalar(@lines), 4, "only one group in account a";
    like $lines[2], $header, "correct header";
    like $lines[3], qr/^\|\s+$gb_id\s+\|\s+Group B\s+/, "first row is group b";
}

################################################################################
list_workspace_group: {
    my $group1 = create_test_group();
    my $group1_id = $group1->group_id;

    my $group2 = create_test_group();
    my $group2_id = $group2->group_id;

    my $ws = create_test_workspace();

    $ws->add_group( group => $group1 );
    ok $ws->has_group( $group1 ), 'Group 1 is in Workspace';

    $ws->add_group( group => $group2 );
    ok $ws->has_group( $group2 ), 'Group 2 is in Workspace';

    my $output = combined_from { eval {
        new_cli('--workspace' => $ws->name)->list_groups()
    } };
    is_last_exit(0);

    my @lines = split("\n",$output);
    
    is scalar(@lines), 5, "two groups in workspace";
    like $lines[2], $header, "correct header";
    like $lines[3], qr/^\|\s+$group1_id\s+\|\s+/, "first row is group 1";
    like $lines[4], qr/^\|\s+$group2_id\s+\|\s+/, "first row is group 1";
}

################################################################################
show_group_config: {
    # No group
    my $output = combined_from {
        eval { new_cli()->show_group_config() }
    };
    like $output, qr/requires a '--group' parameter\./,
        'error message with missing param';

    # Group doesn't exist
    $output = combined_from {
        eval { new_cli( '--group' => '0' )->show_group_config() }
    };
    like $output, qr/No group with ID \d+\./,
        'error message with incorrect group id';

    # Got a group
    my $group = create_test_group();
    $output = combined_from {
        eval { new_cli('--group' => $group->group_id)->show_group_config() }
    };

    ok $output, 'got group settings...';
    like $output, qr/Config for group \w+:/, '... with header';
    like $output, qr/Group Name\s+: \w+/, '... with group name';
    like $output, qr/Group ID\s+: \d+/, '... with group id';
    like $output, qr/Number Of Users\s+: \d+/, '... with users';
    like $output, qr/Primary Account ID\s+: \d+/, '... with account id';
    like $output, qr/Primary Account Name\s+: \w+/, '... with account name';
    like $output, qr/Source\s+: \w+/, '... with source';
}

################################################################################
show_group_members: {
    my $group         = create_test_group();
    my $user          = create_test_user();
    my $email_address = $user->email_address;

    $group->add_user( user => $user );

    my $output = combined_from {
        eval { new_cli( '--group' => $group->group_id )->show_members() }
    };

    ok $output, 'got output...';
    like $output, qr/Members of the \w+ group/, '... with header';
    like $output, qr/\| Email Address \| First \| Last \| Role \|/,
        '... with fields';
    like $output, qr/\Q$email_address\E/, '... with user';
}

################################################################################
delete_a_group: {
    my $group         = create_test_group();

    my $output = combined_from {
        eval { new_cli( '--group' => $group->group_id )->delete_group() }
    };

    ok $output, 'got output...';
    like $output, qr/Deleted group id: \d+/, '... deleted the group';
}

################################################################################
index_all_groups: {
    my $group1        = create_test_group();
    my $group2        = create_test_group();

    my $output = combined_from {
        eval { new_cli( )->index_groups() }
    };

    ok $output, 'got output...';
    like $output, qr/Scheduled \d+ groups for indexing/;
}

################################################################################
sub new_cli { return Socialtext::CLI->new(argv => \@_) }

