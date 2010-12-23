#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;

use YAML;
use Test::Socialtext::Fatal;
use Test::Differences;
use File::Path 'mkpath';
use Socialtext::Paths;
use Socialtext::System qw/shell_run/;
use Socialtext::Schema;
use Socialtext::AppConfig;
use Test::Socialtext;

###############################################################################
# Fixtures: clean base_layout destructive
# - need to start from a clean slate; we're going to build DB from scratch
# - we're destructive; you'll want to recreate the DB when we're done
fixtures(qw( clean base_layout destructive ));

my $test_dir      = Socialtext::AppConfig->test_dir();
my $real_dir      = 'etc/socialtext/db';
my $fake_dir      = "$test_dir/etc/socialtext/db";
my $log_dir       = Socialtext::Paths::log_directory();
my $backup_dir    = Socialtext::Paths::storage_directory('db-backups');
my $START_SCHEMA  = 2;
my $latest_schema = $START_SCHEMA;

# Set up directories and copy schema migrations into our test directory
{
    mkpath $fake_dir unless -d $fake_dir;
    ($latest_schema) = reverse sort { $a <=> $b }
                        map { m/-\d+-to-(\d+)\.sql/ }
                       glob("$real_dir/socialtext-*-to-*.sql");

    for my $cur ($START_SCHEMA .. $latest_schema) {
        my $prev = $cur - 1;
        my $file = "socialtext-$prev-to-$cur.sql";
        open my $in, "$real_dir/$file"
            or die "Can't open $real_dir/$file: $!";
        open my $out, ">$fake_dir/$file"
            or die "Can't open $fake_dir/$file: $!";
        while (<$in>) {
            # change backup directories that don't exist here
            s{/var/www/socialtext/storage/db-backups}{$backup_dir}g;
            print $out $_;
        }
        close $out or die "Can't write to $fake_dir/$file: $!";
    }
}

plan tests => ($latest_schema - $START_SCHEMA) + 1;

# Set up the initial database
diag "loading config...\n";
my $schema_config = YAML::LoadFile("$real_dir/socialtext.yaml");

diag "Creating schema object...\n";
my $schema = Socialtext::Schema->new(%$schema_config);
$schema->{no_add_required_data} = $schema->{quiet} = 1;

diag "Recreating schema...\n";
$schema->recreate(
    'schema-file'    => 't/test-data/socialtext-schema.sql',
    'no_die_on_drop' => 1,
);

# Check each schema
for ( $START_SCHEMA+1 .. $latest_schema ) {
    ok !exception {
        $schema->sync( to_version => $_, no_dump => 1, no_create => 1)
    }, "Schema migration $_";
    if ($@) {
        system("tail -n 20 $log_dir/st-db.log");
        die "Can't continue";
    }
}

# Now check that the final result is the same as socialtext-schema.sql
my $generated_schema = "$test_dir/generated-schema.sql";
shell_run "dump-schema $generated_schema";

my $diff = qx{diff -du $real_dir/socialtext-schema.sql $generated_schema};
is $diff, '', "Zero length diff";

if ($ENV{INSTALL_SCHEMA}) {
    shell_run("cp $generated_schema $real_dir/socialtext-schema.sql");
}
