package Socialtext::Revision::RenderedSideBySideDiff;
# @COPYRIGHT@

# This class just presents the two versions side by side without highlighting

use strict;
use warnings;

use base 'Socialtext::Revision::SideBySideDiff';

sub diff_rows {
    my $self = shift;
    return [{
        before => $self->before_page->to_html,
        after => $self->after_page->to_html,
    }];
}

1;

