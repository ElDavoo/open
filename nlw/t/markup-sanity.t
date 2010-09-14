#!perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::Socialtext tests => 9;
fixtures(qw( empty ));

filters {
    wiki => 'format',
    match => 'wrap_html',
};

my $viewer = new_hub('empty')->viewer;

run_is wiki => 'match';

sub format {
    $viewer->text_to_html(shift)
}

sub wrap_html {
    <<"...";
<div class="wiki">
<p>
$_</p>
</div>
...
}

__DATA__
=== Huggy begin-phrase markers should have effect. (dash)
--- wiki
mmm -2 degrees between today- tomorrow
--- match: mmm <del>2 degrees between today</del> tomorrow

=== Non-huggy begin-phrase markers should have no effect. (dash)
--- wiki
mmm - 2 degrees between today- tomorrow
--- match: mmm - 2 degrees between today- tomorrow

=== Non-huggy end-phrase markers should have no effect. (dash)
--- wiki
mmm -2 degrees between today - tomorrow
--- match: mmm -2 degrees between today - tomorrow

=== Huggy begin-phrase markers should have effect. (asterisk)
--- wiki
mmm *2 degrees between today* tomorrow
--- match: mmm <strong>2 degrees between today</strong> tomorrow

=== Non-huggy begin-phrase markers should have no effect. (asterisk)
--- wiki
mmm * 2 degrees between today* tomorrow
--- match: mmm * 2 degrees between today* tomorrow

=== Non-huggy end-phrase markers should have no effect. (asterisk)
--- wiki
mmm *2 degrees between today * tomorrow
--- match: mmm *2 degrees between today * tomorrow

=== Huggy begin-phrase markers should have effect. (underscore)
--- wiki
mmm _2 degrees between today_ tomorrow
--- match: mmm <em>2 degrees between today</em> tomorrow

=== Non-huggy begin-phrase markers should have no effect. (underscore)
--- wiki
mmm _ 2 degrees between today_ tomorrow
--- match: mmm _ 2 degrees between today_ tomorrow

=== Non-huggy end-phrase markers should have no effect. (underscore)
--- wiki
mmm _2 degrees between today _ tomorrow
--- match: mmm _2 degrees between today _ tomorrow

