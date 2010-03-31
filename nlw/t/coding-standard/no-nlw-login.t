#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use List::MoreUtils qw(any);
use Test::More tests => 1;
use Test::Differences;

# List of things that are OK to include "/nlw/login.html" in them.
my @skip_paths = qw(
    share/migrations/
    share/workspaces/stl10n/
    t/tmp/
);
my %skip_files =
    map { $_ => 1 }
    qw(
        dev-bin/st-create-account-data
        lib/Socialtext/Challenger/STLogin.pm
        share/skin/js-test/s3/t/bz-1379.t.js
        share/skin/js-test/s3/t/bz-1500.t.js
        share/workspaces/wikitests/test_case_login_logout
        t/coding-standard/no-nlw-login.t
        t/live/login-message.t
        t/live/user.t
    );

SKIP: {
    skip 'No `ack` available', 1, unless `which ack` =~ /\w/;

    my @candidates = `ack --follow --nocolor --all -l /nlw/login.html .`;
    chomp @candidates;

    my @bad_files;
    foreach my $file (@candidates) {
        next if (exists $skip_files{$file});
        next if (any { $file =~ /^$_/ } @skip_paths);
        push @bad_files, $file;
    }

    eq_or_diff \@bad_files, [], 'No /nlw/login.html in our source code';

    if (@bad_files) {
        diag <<EOT;
We shouldn't be referencing the login template directly.  Instead,
we should either be:

a) triggering the Authen challenger at /challenge?<url>

b) using the 'error/display.html' error template to display an error
   - see "ST::Handler::Authen->_show_error()" for an example
EOT
    }
}
