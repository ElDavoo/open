# @COPYRIGHT@
package Socialtext::InitHandler;

use strict;
use warnings;

our $VERSION = '0.01';

use File::chdir;
use Socialtext::AppConfig;
use Socialtext::Skin;
use Socialtext::Pluggable::Adapter;
use Socialtext::Workspace;
use Socialtext::System qw(shell_run);
use Fcntl ();
use Socialtext::User::Cache;

sub handler {
    my $r = shift;
    {
        # make all users use the in-memory cache (per process) in Apache
        no warnings 'once';
        $Socialtext::User::Cache::Enabled = 1;
    }

    if (my $proxy = Socialtext::AppConfig->web_services_proxy) {
        $ENV{http_proxy} = $ENV{HTTP_proxy} = $proxy;
    }

    # Disable KeepAlive requests by default, by setting the "nokeepalive"
    # environment var (just like how BrowserMatch does it in Apache configs)
    #
    # This turns them off by default, *but* makes it possible for another part
    # of the system to turn them back on again if needed (by setting
    # 'nokeepalive=>undef').
    $r->subprocess_env(nokeepalive => 1);

    return;
}

sub _remake_all {
    my $remake_time = 10;
    my $stamp_file = Socialtext::Paths::storage_directory('make_ran');
    my $mtime = (stat $stamp_file)[9] || 0;
    if ($mtime < time - $remake_time) {
#         warn "[$$] need to remake ".time."\n";
        # file is missing or out of date; serialize requests
        sysopen my $lock, $stamp_file, Fcntl::O_CREAT|Fcntl::O_RDWR, 0660;
        flock $lock, Fcntl::LOCK_EX;
        $mtime = (stat $lock)[9];
        if ($mtime < time - $remake_time) {
#             warn "[$$] is going to make ".time."\n";
            # we're the first one, run make
            local $Socialtext::System::SILENT_RUN = 1;
            shell_run '-st-make-all @all';
            shell_run '-st-widgets update-all';
            # prevent others holding the lock from running make
            print $lock time."\n";
#             warn "[$$] done make ".time."\n";
        }
#         else {
#             warn "[$$] not stale after all ".time."\n";
#         }
    }
#     else {
#         warn "[$$] no make needed ".time."\n";
#     }
}

1;

__END__

=head1 NAME

Socialtext::InitHandler - A PerlInitHandler for Socialtext

=head1 SYNOPSIS

  PerlInitHandler  Socialtext::InitHandler

=head1 DESCRIPTION

This module is the place to put per-request initialization code.  It
should only be called for requests which are generating dynamic
content.  It does not need to be called when serving static files.

It does the following:

=over 4

=item *

Re-generates the javascript files if in a development mode.

=item *

Disables KeepAlive requests, but in such a way that they I<could> be re-enabled
by another part of the system if necessary.  This allows for us to default to
"no KeepAlives", but to turn them back on when needed.

Although Apache2 provides a way to default KeepAlives to off and then turn
them on when needed, Apache1 does B<not>.  Thus, this work-around.

=back

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2005 Socialtext, Inc., All Rights Reserved.

=cut
