#!/usr/bin/perl
# @COPYRIGHT@
use warnings;
use strict;

#
# produce an anonymized dump of the user graph in the database.
# Correct as of schema version 94.
#
# Usage: sudo -u www-data ./anon-user-graph-dump.pl | bzip2 -c - > anon-user-graph.yaml.bz2
#

use Socialtext::SQL qw/get_dbh/;
use YAML qw/Dump/;

my $dbh = get_dbh();

my @queries = split "\n",<<EOQ;
SELECT * FROM "Role";
SELECT account_id FROM "Account";
SELECT workspace_id,account_id FROM "Workspace";
SELECT * FROM "System";
SELECT * FROM account_plugin;
SELECT * FROM group_account_role;
SELECT * FROM group_workspace_role;
SELECT group_id,primary_account_id FROM groups;
SELECT user_id,primary_account_id FROM users NATURAL JOIN "UserMetadata";
SELECT * FROM user_account_role;
SELECT * FROM user_group_role;
SELECT * FROM user_workspace_role;
SELECT * FROM workspace_plugin;
SELECT * FROM workspace_plugin_pref;
EOQ

for my $query (@queries) {
	my $sth = $dbh->prepare($query);
	$sth->execute();
	# make keys lexical for readability
	print Dump({
		aa_table => "Role",
		bb_names => $sth->{NAME},
		zz_data => $sth->fetchall_arrayref(),
	});
}
