package Socialtext::JSON::Proxy::Helper;
# @COPYRIGHT@
use strict;
use warnings;

use File::Temp qw/mkdtemp/;
use Socialtext::Paths;
use Socialtext::AppConfig;

sub ClearForUser {
    my $class = shift;
    my $user_id = shift;
    PurgeCache();
}

sub ClearForAccount {
    my $class = shift;
    my $account_id = shift;
    PurgeCache();
}

sub PurgeCache {
    my $class = shift;

    my $pidfile = Socialtext::AppConfig->pid_file_dir . "/json-proxy.pid";
    system "start-stop-daemon --stop --quiet --oknodo --pidfile $pidfile --signal USR1";

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
  Socialtext::JSON::Proxy::Helper->ClearForUser($user_id);
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
