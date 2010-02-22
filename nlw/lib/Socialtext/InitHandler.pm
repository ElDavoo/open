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
use Fcntl ':flock';
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

sub _regen_combined_js {
    my $r = shift;

    # Figure out what skin to build
    my ($ws_name) = $r->uri =~ m{^/([^/]+)/index\.cgi$};
    my $workspace = $ws_name ? Socialtext::Workspace->new(name=>$ws_name) : undef;
    my $skin_name = $workspace ? $workspace->skin_name : 's3';
    my $skin      = Socialtext::Skin->new(name => $skin_name);

    for my $dir ($skin->make_dirs) {
        local $CWD = $dir;

        my $semaphore = "$dir/build-semaphore";
        open( my $lock, ">>", $semaphore )
            or die "Could not open $semaphore: $!\n";
        flock( $lock, LOCK_EX )
            or die "Could not get lock on $semaphore: $!\n";
        system( 'make', 'all' ) and die "Error calling make in $dir: $!";
        close($lock);
    }
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
