#!perl
# @COPYRIGHT@
use strict;
use warnings;
use Socialtext::AppConfig;
use Test::Socialtext tests => 19;

fixtures(qw( db ));

use_ok 'Socialtext::Encode';

binmode STDERR, 'utf8'; # So diagnostics don't complain

# Socialtext::Encode::is_valid_utf8
{
    my $invalid = "\x96 \x92";
    ok not(Encode::is_utf8($invalid)),
        "bad string doesn't start out with the utf8 flag set";
    ok not(Socialtext::Encode::is_valid_utf8($invalid)), "doesn't validate";
    ok not(Encode::is_utf8($invalid)), "still no flag set on original string";

    my $valid = Encode::decode_utf8("【ü】");
    ok Encode::is_utf8($valid), 'Good text has utf8 flag';
    ok Socialtext::Encode::is_valid_utf8($valid), 'validates';
    ok Encode::is_utf8($valid), 'still has utf8 flag';
}

# Set up the bogus-data-having page:
use File::Copy;
use File::Path;
my $hub          = create_test_hub();
my $ws_name      = $hub->current_workspace->name();
my $test_dir     = Socialtext::AppConfig->test_dir();
my $bad_utf8_dir = "$test_dir/root/data/$ws_name/bad_utf8";
File::Path::mkpath $bad_utf8_dir or die $!;
copy "t/attachments/bad-8bit.txt", "$bad_utf8_dir/123.txt" or die $!;
symlink "123.txt", "$bad_utf8_dir/index.txt";

# Check noisy_decode by using pages->new_from_name:
{
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };
    my $page = $hub->pages->new_from_name('bad_utf8');
    my $output = $page->to_html;
    like $output, qr/<div\s+class="wiki">.*asdf/s,
        'did not cause infinite loop in the Perl interpreter';
    unlike $output, qr/\x92\n/, 'non-UTF-8 filtered';
    like $warnings[0], qr/bad_utf8\/123\.txt: doesn't seem to be valid utf-8/,
        'emitted warnings - to help track down bad data';
    like $warnings[1], qr/Treating as/, 'Guessing an encoding.';

    # Note: due to some unknown code change, we get warnings twice now
    # maybe this shouldn't be the case.
    ok @warnings == 2, '...but it\'s not too noisy.';
    diag @warnings.join("\n----------\n");
}

# Socialtext::Encode::ensure_is_utf8
{
    my $orig = "Tüst";
    my $str = $orig;

    ok !Encode::is_utf8($str), "plain text does not have the utf8 flag";
    is 5, length($str), "length works bytewise";

    $str = Socialtext::Encode::ensure_is_utf8($str);
    ok Encode::is_utf8($str), "decoding sets the flag";
    ok !Encode::is_utf8($orig), "orig's flag is left alone";

    my $str2 = Socialtext::Encode::ensure_is_utf8($str);
    ok Encode::is_utf8($str2), "ensure_is_utf8 is idempotent";
    is $str, $str2, "both strings are equal";
}

{
    my $orig = "\x83\x8d\x83\x7b\x83\x67"; # shift-jis for ロボト
    my $expected = Encode::decode_utf8("ロボト");
    my $actual = Socialtext::Encode::guess_decode($orig);
    is $actual, $expected, "guessed shift-jis encoding";
}
