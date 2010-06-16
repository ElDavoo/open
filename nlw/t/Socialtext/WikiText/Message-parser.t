#!/usr/bin/perl
# @COPYRIGHT@
# This test is for the parser events, not the formatting per se.
# SEE ALSO t/formatter/signals-html.t
use strict;
use warnings;
# do *not* `use utf8` here
use Test::More tests => 3 + 7 + 2*16 + 7;

use ok 'Socialtext::WikiText::Parser::Messages';
use ok 'Socialtext::WikiText::Emitter::Messages::Canonicalize';
use ok 'Socialtext::WikiText::Emitter::Messages::HTML';

my @links;

check_hashmark_canonicalization: {
    my $parser = make_parser('Canonicalize');
    isa_ok $parser, 'Socialtext::WikiText::Parser::Messages';

    my $body = $parser->parse('hashtags #one {hashtag: two} no#not');
    is $body, 'hashtags {hashtag: one} {hashtag: two} no#not',
        'parsed alright';
    is scalar(@links), 2, 'two links';
    is $links[0]{wafl_type}, 'hashmark', 'hashtag one';
    is $links[0]{text}, 'one';
    is $links[1]{wafl_type}, 'hashtag', 'hashtag two';
    is $links[1]{text}, 'two';
}

for my $type (qw(Canonicalize HTML)) {
    my $parser = make_parser($type);
    isa_ok $parser, 'Socialtext::WikiText::Parser::Messages';

    my $content = $parser->parse('{user: 1} {link: admin [Admin Wiki]} {user: 2} "Named"{link: foo [bar]} nomatch#please #tag {hashtag: other tag}');
    
    ok $content, 'parsed alright';
    my $hashmark_re;
    if ($type eq 'Canonicalize') {
        $hashmark_re = qr/{hashtag: ?tag}/;
    }
    else {
        $hashmark_re = qr{#<a href="[^"]+">tag</a>};
    }
    like $content, qr/please $hashmark_re /, 'hashmark placed OK';
    unlike $content, qr/^$hashmark_re/,
        'no spurrious hashtag at the beginning (regression)';
    is scalar(@links), 6, 'six links';

    is $links[0]{wafl_type}, 'user';
    is $links[0]{user_string}, '1', 'user 1 is first';

    is $links[1]{wafl_type}, 'link', 'then a link';

    is $links[2]{wafl_type}, 'user';
    is $links[2]{user_string}, '2', 'then user 2';

    is $links[3]{wafl_type}, 'link', 'then a link';
    is $links[3]{text}, 'Named', 'the link is named';

    is $links[4]{wafl_type}, 'hashmark', 'then a hashtag';
    is $links[4]{text}, 'tag', 'tag is named';

    is $links[5]{wafl_type}, 'hashtag', 'then a hashtag';
    is $links[5]{text}, 'other tag', 'tag is named';
}

# Make sure hashtags are only matched inbetween spaces
check_hashmark_after_spaces: {
    my $parser = make_parser('HTML');
    isa_ok $parser, 'Socialtext::WikiText::Parser::Messages';

    my $content = $parser->parse('#yesmatch1 a#nomatch #yesmatch2@ #yesmatch3');
    ok $content, 'parsed';
    like $content, qr/ a#nomatch /, 'nomatch left alone';
    is scalar(@links), 3, 'three tags';
    is $links[0]{text}, 'yesmatch1', 'yesmatch1';
    is $links[1]{text}, 'yesmatch2', 'yesmatch2';
    is $links[2]{text}, 'yesmatch3', 'yesmatch3';
}

sub make_parser {
    @links = ();
    my $full_type = 'Socialtext::WikiText::Emitter::Messages::'.shift;
    my $emitter = $full_type->new(
        callbacks => {
            noun_link => sub {push @links, $_[0]},
        }
    );
    return Socialtext::WikiText::Parser::Messages->new(receiver => $emitter);
}
