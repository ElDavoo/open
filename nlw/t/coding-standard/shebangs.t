#!perl
# @COPYRIGHT@
use warnings;
use strict;
use Test::More;

plan tests => 2;

my @perlfail;
my @shfail;
my $p_erl = '/usr/bin/p'.'erl';
my $local_p_erl = '/usr/local/bin/p'.'erl';
my $s_h = '/bin/s'.'h';
my $perl_re = qr/(?:$p_erl|$local_p_erl)/;
my $sh_re = qr/$s_h/;

my %IGNORE_PERL = map {$_ => 1} qw(
    nlw/docs/INSTALL.apache-perl
    nlw/docs/INSTALL.troubleshooting
    nlw/docs/INSTALL.st-dev
    plugins/VimColor/debian/rules
    plugins/Latex/debian/rules
);

my %IGNORE_SH = map {$_=>1} qw(
    socialtext-reports/Makefile
    appliance/libsocialtext-appliance-perl/Makefile
    nlw/build/tmp/Makefile.perl
);

chdir $ENV{ST_CURRENT};
local $/ = "\0"; # nulls
my @files = `find . -type f -print0`;
chomp @files; # strip nulls

$/ = undef; # input slurp
for my $f (@files) {
    $f =~ s{^\./}{}; # IT'S A BIRD: _._ \./
    next if (
        $f =~ m{\.git.*} or
        $f =~ m{\.sw[mnop]$} or # vim tempfile
        $f =~ m{\.(?:rej|orig|bak)$} or # tempfile
        $f =~ m{^~} or # tempfile
        $f =~ m{/DEBIAN/} or # .deb temp stuff
        $f =~ m{(?:amd64|i386)\.build$}
    );

    my $text = do { local @ARGV = $f; <> };

    push @perlfail,$f if (!$IGNORE_PERL{$f} && $text =~ $perl_re);
    push @shfail,$f   if (!$IGNORE_SH{$f}   && $text =~ $sh_re);
}

is scalar(@perlfail),0,"no $p_erl"
    or do { diag "Failing files:"; diag "\t$_" for @perlfail; };
is scalar(@shfail),0,"no $s_h"
    or do { diag "Failing files:"; diag "\t$_" for @shfail; };
