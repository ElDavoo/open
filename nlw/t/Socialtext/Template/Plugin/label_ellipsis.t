#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Template;
use Test::More tests => 10;

sub truncate_ok($$$;$) {
    my ($text, $length, $expected, $msg) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    $msg ||= "truncated: $expected";

    my $template = "[%- USE label_ellipsis -%][%- text | label_ellipsis($length) -%]";
    my $received = '';

    my $tt = Template->new(
        PLUGIN_BASE => 'Socialtext::Template::Plugin',
    );
    $tt->process(\$template, { text => $text }, \$received) || die $tt->error;
    is $received, $expected, $msg;
}

truncate_ok 'abcd',         15, 'abcd',        'No ellipsis on short label';
truncate_ok 'abcd',          2, 'ab...',       'Ellipsis on length 2 label';
truncate_ok 'abc def',       4, 'abc...',      'Ellipsis breaks on space';
truncate_ok 'abc def',       6, 'abc...',      'Ellipsis breaks on space if short one';
truncate_ok 'abc def',       7, 'abc def',     'No ellipsis on exact length';
truncate_ok 'abc  def efg', 11, 'abc  def...', 'Whitespace preserved between words';
truncate_ok 'abc def',       0, '...',         'Ellipsis only if length is 0';
truncate_ok 'abc def',       2, 'ab...',       'Proper short word ellipsis with space';

#utf8
my $singapore = join '', map { chr($_) } 26032, 21152, 22369;
truncate_ok $singapore, 3, $singapore, 'UTF8 not truncated';
truncate_ok $singapore, 2, substr($singapore, 0, 2) . '...', 'UTF8 truncated with ellipsis';

