#!perl
# @COPYRIGHT@
use warnings;
use strict;
use Test::Socialtext tests => 12;
use Test::Differences;
use File::Temp qw/tempdir tempfile/;
use Fatal qw/open/;

fixtures(qw(base_layout));

my $dir = tempdir(CLEANUP => 1);

happy_path: {
    my $script = <<'PERL';
        use Socialtext::System::TraceTo '##FILE##';
        print "redirected!\n";
        warn "warned!\n";
PERL
    my $o = run_as_script(happy_path => $script);
    eq_or_diff $o, "before script\nredirected!\nwarned!\n";
}

late_redir: {
    my $script = <<'PERL';
        use Socialtext::System::TraceTo;
        warn "# ignore this\n";
        print "# ignore this\n";
        Socialtext::System::TraceTo::logfile('##FILE##');
        print "redirected some more!\n";
        warn "warned some more!\n";
PERL
    my $o = run_as_script(late_redir => $script);
    eq_or_diff $o, "before script\nredirected some more!\nwarned some more!\n";
    unlike $o, qr/ignore this/m, "pre logfile output not logged";
}

check_sidestep: {
    local $ENV{PERLCHECK} = 1;
    my $script = <<'PERL';
        use Socialtext::System::TraceTo '##FILE##';
        warn "# ignore this\n";
        print "# ignore this\n";
PERL
    my $o = run_as_script(check_sidestep => $script);
    eq_or_diff $o, "before script\n";
    unlike $o, qr/ignore this/m, "not traced because in perlcheck mode";
}

pass "done";

sub run_as_script {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $name = shift;
    my $code = shift;


    my ($log_fh, $logfile) = tempfile(DIR => $dir);
    print $log_fh "before script\n";
    close $log_fh;

    my ($script_fh, $script_name) = tempfile(DIR => $dir);
    $code =~ s/##FILE##/$logfile/sg;
    print $script_fh $code;
    close $script_fh;

    my $rc = system($^X, '-w', '-Mstrict', $script_name);
    ok !$rc, "$name ran ok";
    ok -f $logfile && -r _, "$name created log file";

    open $log_fh, '<', $logfile;

    my $output = do { local $/; <$log_fh> };
    close $log_fh;

    return $output;
}
