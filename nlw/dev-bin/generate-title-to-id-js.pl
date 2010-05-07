#!/usr/bin/perl
# @COPYRIGHT@
use warnings;
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Socialtext::IntSet; # if you don't have this, try vec() or Judy::1

# FROM Socialtext::String:
my $invalid_re = qr/[^\p{Letter}\p{Number}\p{ConnectorPunctuation}\pM]+/;

my $unicore_gc_sc = '/usr/share/perl/5.8.7/unicore/lib/gc_sc';
my $Letter               = do "$unicore_gc_sc/L.pl";
my $Number               = do "$unicore_gc_sc/N.pl";
my $ConnectorPunctuation = do "$unicore_gc_sc/Pc.pl";
my $M                    = do "$unicore_gc_sc/M.pl";    # aka Mark

my $fine = Socialtext::IntSet->new;

sub explode {
    my @lines = split("\n", $_[0]);
    for my $line (@lines) {
        my ($from, $to) = ($line =~ /^([0-9A-F]{4})\s+([0-9A-F]{4})?\s*/);
        next unless $from;
        if ($from && $to) {
            $fine->set($_) for (oct("0x$from") .. oct("0x$to"));
        }
        else {
            $fine->set(oct("0x$from"));
        }
    }
}

explode($Letter);
explode($Number);
explode($ConnectorPunctuation);
explode($M);

#warn "got ".$fine->count." fine characters out of 65536\n";
die "first can't be zero" if $fine->nth(1) == 0;

my $all = Socialtext::IntSet->new;
$all->set($_) for (0 .. 0xFFFF);

# invert the set since the majority of BMP1 characters are Letter-classed.
my $excl = $all->subtract($fine);
#warn "inverse has ".$excl->count." characters out of 65536\n";
#warn "both sets: ".($excl->count + $fine->count)."\n";

my @ranges;
{
    my $gen = $excl->generator;
    my ($n, $start, $stop);
    $start = $stop = $gen->();
    while (defined($n = $gen->())) {
        if ($n == $stop+1) {
            $stop++;
        }
        else {
            push @ranges, $start,$stop;
            ($start,$stop) = ($n,$n);
        }
    }
    push @ranges, $start,$stop;
}

print "/* DO NOT EDIT THIS FUNCTION! run $0 instead */\n";
print "function page_title_to_page_id (str) {\n";
print "    str = str.replace(/[";
while (my ($start,$stop) = splice @ranges,0,2) {
    if ($start == $stop) {
        printf '\u%04X', $start;
    }
    else {
        printf '\u%04X-\u%04X', $start, $stop;
    }
}
print "]+/g,'_');\n";
print <<EOJS;
    str = str.replace(/_+/g, '_');
    str = str.replace(/(^_|_\$)/g, '');
    if (str == '0') str = '_';
    if (str == '') str = '_';
    return str.toLocaleLowerCase();
} /* function page_title_to_page_id */
EOJS
