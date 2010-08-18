#!perl
use warnings;
use strict;
use Test::More tests => 60;
use Test::Exception;
use utf8;

use ok 'Socialtext::File::Stringify::text_html';

my $base_dir = 't/Socialtext/File/stringify_data/html';

sub to_str { Socialtext::File::Stringify::text_html->to_string(@_) };

sub has_japanese_content ($$;$) {
    my ($buf, $ct, $name) = @_;
    $name ||= $ct;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    ok $buf =~ /\Q日本語/, "$name found decoded title"; # "Japanese"
    ok $buf =~ /\Qキーワード/, "$name found meta keywords"; # "keywords"
    ok $buf =~ /\Q説明/, "$name found meta description"; # "description"
    ok $buf =~ /\Qこのページは${ct}でいる/,
        "$name body text"; # "this page is $charset"
    ok $buf =~ m#\Qhttp://socialtext.com/?$ct#i, "$name a-tag link href";
    ok $buf =~ /\Qリンクテキスト/, "$name a-tag link text"; # "link text"
}

sub has_danish_content ($$;$) {
    my ($buf, $ct, $name) = @_;
    $name ||= $ct;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    ok $buf =~ /\QDansk/, "$name decoded title";
    ok $buf =~ /\Qsøgeord/, "$name meta keywords"; # "keywords"
    ok $buf =~ /\Qbeskrivelse/, "$name meta description"; # "description"
    like $buf, qr/\Qdenne side er $ct. Her er et billede af en kanin med en pandekage på hovedet. Æ!/, "$name body text"; # "this page is $charset. Here is a picture of a rabbit with a pancake on it's head. Ae!"
    ok $buf =~ m#\Qhttp://socialtext.com/?$ct#i, "$name a-tag link href";
    ok $buf =~ /\Qlinktekst/, "$name a-tag link text"; # "link text"
}

missing: {
    my $filename = $base_dir .'/does-not-exist.html';
    my $buf;
    lives_ok {
        to_str(\$buf, $filename, 'text/html; charset=UTF-8');
    } 'stringify with explicit charset';
    ok $buf eq '', "empty buffer on missing file";
}

utf8: {
    my $filename = $base_dir .'/japanese-utf8.html';
    my $buf;
    lives_ok {
        to_str(\$buf, $filename, 'text/html; charset=UTF-8');
    } 'stringify with explicit charset';
    has_japanese_content($buf, 'UTF-8');
}

utf8_with_guess: {
    my $filename = $base_dir .'/japanese-utf8.html';
    my $buf;
    lives_ok {
        to_str(\$buf, $filename, 'text/html');
    } 'stringify with absent charset (derived by meta header), guess utf8';
    has_japanese_content($buf, 'UTF-8', "UTF-8-guessed");
}

utf16_no_guess: {
    my $filename = $base_dir .'/japanese-utf16.html';
    my $buf;
    lives_ok {
        to_str(\$buf, $filename, 'text/html; charset=UTF-16LE');
    } 'stringify with explicit UTF-16LE charset';
    has_japanese_content($buf, 'UTF-16', "UTF-16LE");
}

utf16_guess: {
    my $filename = $base_dir .'/japanese-utf16.html';
    my $buf;
    lives_ok {
        to_str(\$buf, $filename, 'text/html');
    } 'stringify UTF-16 with absent charset (derived by meta header)';
    has_japanese_content($buf, 'UTF-16', "UTF-16LE-guessed");
}

sjis: {
    my $filename = $base_dir .'/japanese-shiftjis.html';
    my $buf;
    lives_ok {
        to_str(\$buf, $filename, 'text/html; charset=Shift_JIS');
    } 'stringify with explicit Shift_JIS charset';
    has_japanese_content($buf, 'Shift-JIS', 'Shift_JIS');
}

sjis_with_guess: {
    my $filename = $base_dir .'/japanese-shiftjis.html';
    my $buf;
    lives_ok {
        to_str(\$buf, $filename, 'text/html');
    } 'stringify with absent charset (derived by meta header), guess sjis';
    has_japanese_content $buf, 'Shift-JIS', 'Shift_JIS-guessed';
}

danish_utf8_with_guess: {
    my $filename = $base_dir .'/danish-utf8.html';
    my $buf;
    lives_ok {
        to_str(\$buf, $filename, 'text/html');
    } 'stringify with absent charset (derived by meta header), guess utf8';
    has_danish_content($buf, 'UTF-8', "UTF-8-danish");
}

danish_iso_8859_1_with_guess: {
    my $filename = $base_dir .'/danish-iso-8859-1.html';
    my $buf;
    lives_ok {
        to_str(\$buf, $filename, 'text/html');
    } 'stringify with absent charset (derived by meta header), guess iso';
    has_danish_content($buf, 'ISO-8859-1', "ISO-8859-1-danish");
}

pass 'done';
