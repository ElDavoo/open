#!/usr/bin/perl
# @COPYRIGHT@
# This test is for the parser events, not the formatting per se.
# SEE ALSO t/formatter/signals-html.t
use strict;
use warnings;
# do *not* `use utf8` here
use Test::More tests => 6 + 7 + 4 + 3*29 + 7;

use ok 'WikiText::Socialtext';
use ok 'Socialtext::WikiText::Parser::Messages';
use ok 'Socialtext::WikiText::Emitter::Messages::Solr';
use ok 'Socialtext::WikiText::Emitter::Messages::Canonicalize';
use ok 'Socialtext::WikiText::Emitter::Messages::HTML';

# there will be things that need fixing ("a"-phrases, for example) if we move
# beyond 0.14.  Nothing insurmountable, just want to make sure we address it
# and not just blindly upgrade.
is $WikiText::Socialtext::VERSION, '0.14', 'WikiText::Socialtext 0.15 and above break our stuff :(';

my @noun_links;
my @href_links;

check_hashmark_canonicalization: {
    my $parser = make_parser('Canonicalize');

    my $body = $parser->parse('hashtags #one {hashtag: two} no#not');
    is $body, 'hashtags {hashtag: one} {hashtag: two} no#not',
        'parsed alright';
    is scalar(@noun_links), 2, 'two links';
    is $noun_links[0]{wafl_type}, 'hashmark', 'hashtag one';
    is $noun_links[0]{text}, 'one';
    is $noun_links[1]{wafl_type}, 'hashtag', 'hashtag two';
    is $noun_links[1]{text}, 'two';
}

check_nongreedy_a_in_solr: {
    my $parser = make_parser('Solr');
    my $content = $parser->parse('"http://example.com/1"<http://example.com/2>');
    ok $content, 'parsed';
    is $content, '"http://example.com/1"<http://example.com/2>';
    is scalar(@href_links), 1;
}

for my $type (qw(Solr Canonicalize HTML)) {
    my $parser = make_parser($type);

    my $content = $parser->parse(
        '{user: 1} {link: admin [Admin Wiki]} {user: 2} '
       .'"Named"{link: foo [bar]} nomatch#please #tag {hashtag: other taag} '
       .'http://example.com/1 '
       .'"awesomeness"<http://awesome.com/2> '
       .'"wikked"<http://google.com/3> http://example.com/4 '
       .'incarnate'
    );
    
    ok $content, "$type emitted alright";
    my $hashmark_re;
    if ($type eq 'Canonicalize') {
        $hashmark_re = qr/{hashtag: ?tag}/;
    }
    elsif ($type eq 'Solr') {
        $hashmark_re = qr/\btag\b/;
    }
    else {
        $hashmark_re = qr{#<a href="[^"]+">tag</a>};
    }
    like $content, qr/please $hashmark_re /, "$type hashmark placed OK";
    unlike $content, qr/^$hashmark_re/,
        "$type no spurrious hashtag at the beginning (regression)";
    is scalar(@noun_links), 6, "$type six links";

    is $noun_links[0]{wafl_type}, 'user', "$type has user wafl first";
    is $noun_links[0]{user_string}, '1', 'user 1 is first';

    is $noun_links[1]{wafl_type}, 'link', "$type then a link";

    is $noun_links[2]{wafl_type}, 'user', "$type has user wafl third";
    is $noun_links[2]{user_string}, '2', "$type then user 2";

    is $noun_links[3]{wafl_type}, 'link', "$type then a link";
    is $noun_links[3]{text}, 'Named', "$type the link is named";

    is $noun_links[4]{wafl_type}, 'hashmark', "$type then a hashtag";
    is $noun_links[4]{text}, 'tag', "$type tag is named";

    is $noun_links[5]{wafl_type}, 'hashtag', "$type then a hashtag";
    is $noun_links[5]{text}, 'other taag', "$type tag is named";

    {
        is scalar(@href_links), 4, "$type got href links";
        is $href_links[0]{type}, 'a', "$type a phrase";
        is $href_links[0]{text}, '', "$type label is empty";
        is $href_links[0]{attributes}{href}, 'http://example.com/1', "$type href";

        is $href_links[1]{type}, 'a', "$type a phrase";
        is $href_links[1]{text}, 'awesomeness', "$type label is not empty";
        is $href_links[1]{attributes}{href}, 'http://awesome.com/2', "$type href";

        is $href_links[2]{type}, 'a', "$type a phrase";
        is $href_links[2]{text}, 'wikked', "$type label";
        is $href_links[2]{attributes}{href}, 'http://google.com/3', "$type href";

        is $href_links[3]{type}, 'a', "$type a phrase";
        is $href_links[3]{text}, '', "$type label is empty";
        is $href_links[3]{attributes}{href}, 'http://example.com/4', "$type href";
    }
}

# Make sure hashtags are only matched inbetween spaces
check_hashmark_after_spaces: {
    my $parser = make_parser('HTML');

    my $content = $parser->parse('#yesmatch1 a#nomatch #yesmatch2@ #yesmatch3');
    ok $content, 'parsed';
    like $content, qr/ a#nomatch /, 'nomatch left alone';
    is scalar(@noun_links), 3, 'three tags';
    is $noun_links[0]{text}, 'yesmatch1', 'yesmatch1';
    is $noun_links[1]{text}, 'yesmatch2', 'yesmatch2';
    is $noun_links[2]{text}, 'yesmatch3', 'yesmatch3';
}

sub make_parser {
    @noun_links = ();
    @href_links = ();
    my $full_type = 'Socialtext::WikiText::Emitter::Messages::'.shift;
    my $emitter = $full_type->new(
        callbacks => {
            noun_link => sub {push @noun_links, $_[0]},
            href_link => sub {push @href_links, $_[0]},
        }
    );
    my $p = Socialtext::WikiText::Parser::Messages->new(receiver => $emitter);
    isa_ok $p, 'Socialtext::WikiText::Parser::Messages';
    return $p;
}
