#!perl
# @COPYRIGHT@
use warnings;
use strict;
use Test::More;

plan tests => 3;

my (@perlfail, @megaperlfail, @shfail);
my $perl_re = qr{/usr(?:/local)?/bin/perl};
my $megaperl_re = qr{/opt/perl/[^/]+/bin/perl};
my $sh_re = qr{/bin/\bsh};

my %IGNORE_PERL = map {$_ => 1} qw(
    nlw/docs/INSTALL.apache-perl
    nlw/docs/INSTALL.troubleshooting
    nlw/docs/INSTALL.st-dev
    plugins/VimColor/debian/rules
    plugins/Latex/debian/rules
    nlw/t/coding-standard/shebangs.t
);

my %IGNORE_MEGAPERL = map { $_ => 1 } qw(
    appliance/debian/rules
    appliance/st-appliance-update/debian/postinst
    appliance/st-appliance-update/debian/rules
    appliance/st-perf-tools/debian/rules
    plugins/debian/rules
    socialtext-reports/debian/postinst
    appliance/libsocialtext-appliance-perl/debian/rules
    appliance/libsocialtext-appliance-perl/debian/postinst
    socialtext-skins/debian/rules
);

my %IGNORE_SH = map {$_=>1} qw(
    socialtext-reports/Makefile
    appliance/libsocialtext-appliance-perl/Makefile
);

chdir $ENV{ST_CURRENT};
local $/ = "\0"; # nulls
my @files = `find . -type f -print0`;
chomp @files; # strip nulls

sub gitignored {
    my $f = shift;
    `git ls-files --ignored -o --exclude "$f"` ? 1 : 0;
}

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

    push @perlfail,$f if (!$IGNORE_PERL{$f} && $text =~ $perl_re && !gitignored($f));
    push @megaperlfail,$f if (!$IGNORE_MEGAPERL{$f} && $text =~ $megaperl_re && !gitignored($f));
    push @shfail,$f if (!$IGNORE_SH{$f} && $text =~ $sh_re && !gitignored($f));
}

is scalar(@perlfail),0,"no hard-coded perl paths"
    or do { diag "Failing files:"; diag "\t$_" for @perlfail; };
is scalar(@megaperlfail),0,"no hard-coded megaperl paths"
    or do { diag "Failing files:"; diag "\t$_" for @megaperlfail; };
is scalar(@shfail),0,"no /bin/"."sh"
    or do { diag "Failing files:"; diag "\t$_" for @shfail; };