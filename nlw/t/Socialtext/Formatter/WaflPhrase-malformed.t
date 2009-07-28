#!perl -w
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 1;
fixtures( 'admin' );

filters {
    wiki => 'format',
};

my $hub = new_hub('admin');
my $viewer = $hub->viewer;

run_is wiki => 'match';

sub format {
    $viewer->text_to_html(shift)
}

__DATA__
=== labels on wafl phrases should not be greedy
--- wiki
^Malformed Header

one
two
three

--- match
<div class="wiki">
^Malformed Header
<br /><p>
one<br />
two<br />
three</p>
</div>

