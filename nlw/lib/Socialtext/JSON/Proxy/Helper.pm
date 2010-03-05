package Socialtext::JSON::Proxy::Helper;
# @COPYRIGHT@
use strict;
use warnings;

use File::Temp qw/mkdtemp/;
use Socialtext::Paths;
use Socialtext::AppConfig;
use Socialtext::File;
use File::Find qw(find);

our $cache_dir = Socialtext::Paths::storage_directory('json_cache');

sub ClearMemoryCache {
    my $class = shift;
    my $pidfile = Socialtext::AppConfig->pid_file_dir . "/json-proxy.pid";
    if (-f $pidfile) {
        my $pid = Socialtext::File::get_contents($pidfile);
        system "kill -USR1 $pid";
    }
}

sub ClearForUsers {
    my $class = shift;
    my %user_ids = map { $_ => 1 } @_;

    $class->ClearMemoryCache;

    # Purge each user's file-based cache
    my $cache_dir = Socialtext::Paths::storage_directory('json_cache');
    if (-d $cache_dir) {
        find({
            wanted => sub {
                my $filename = $_;
                my ($id) = $filename =~ m{\.(\d+)$};
                if ($id and $user_ids{$id}) {
                    unlink $filename;
                }
            }
        }, $cache_dir);
    }
}

# XXX: Purging the entire JSON cache is not a good idea here, instead we 
# should create a job that purges the cache for all group or account members

sub ClearForAccount {
    my $class = shift;
    my $account_id = shift;
    $class->PurgeCache(); # just purge the entire cache
}

sub ClearForGroup {
    my $class = shift;
    my $group_id = shift;
    $class->PurgeCache(); # just purge the entire cache
}

sub PurgeCache {
    my $class = shift;
    $class->ClearMemoryCache;

    my $cache_dir = Socialtext::Paths::storage_directory('json_cache');
    if (-d $cache_dir) {
        my $tmp_dir = mkdtemp("$cache_dir.purge.XXXXXX");
        rename $cache_dir => $tmp_dir
            or die "can't rename cache dir to $tmp_dir: $!";
    }

    return $cache_dir;
}

1;

__END__

=head1 NAME

Socialtext::JSON::Proxy::Helper

=head1 SYNOPSIS

  Socialtext::JSON::Proxy::Helper->PurgeCache
  # Deprecated:
  Socialtext::JSON::Proxy::Helper->ClearForUsers($user_id1, $user_id2);
  Socialtext::JSON::Proxy::Helper->ClearForAccount($account_id);

=head1 DESCRIPTION

Contains code that is directly callable by the main NLW app for modifying the JSON Proxy Cache.

=head1 METHODS

=head2 PurgeCache

Purge the entire JSON Proxy Cache.  Will create directories of the form
"json_cache.purge.XXXXXX" that will need to be cleaned up by some periodic
process (e.g. cron).  C<st-remove-expired-proxy-cache> will do this on
appliances.

=cut
