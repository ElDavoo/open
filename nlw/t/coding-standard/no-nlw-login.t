#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::More tests => 1;
use Test::Differences;

# List of things that are OK to include "/nlw/login.html" in them.
my %exclude =
    map { $_ => 1 }
    qw(
        dev-bin/st-create-account-data
        lib/Socialtext/Challenger/STLogin.pm
        t/coding-standard/no-nlw-login.t
    );

SKIP: {
    skip 'No `ack` available', 1, unless `which ack` =~ /\w/;

    my @bad_files = `ack --follow --nocolor --all -l /nlw/login.html .`;
    chomp @bad_files;

    @bad_files = grep { !exists $exclude{$_} } @bad_files;

    eq_or_diff \@bad_files, [], 'No /nlw/login.html in our source code';

    if (@bad_files) {
        diag <<EOT;
We shouldn't be referencing the login template directly.  Instead,
we should either be:

a) triggering the Authen challenger at /challenge?<url>

b) using the ??? error template to display an error
EOT
    }
}
