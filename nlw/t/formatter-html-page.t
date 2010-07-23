#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 6;
fixtures('admin');
use Socialtext::Encode;

my $hub = new_hub('admin');

{
    my $name = "Formatter Test for html-page wafl";
    my $page = $hub->pages->new_from_name($name);

    my $attachment =
        $hub->attachments->new_attachment( page_id => $page->id,
                                       filename => 'html-page-wafl.html',
                                     );
    $attachment->save('t/attachments/html-page-wafl.html');
    $attachment->store( user => $hub->current_user );

    $page->metadata->Subject($name);
    $page->metadata->update( user => $hub->current_user );
    # Put some dummy content in. run_tests() will replace it later.
    $page->content('foo');
    $page->store( user => $hub->current_user );

    my @tests =
        ( [ "{html-page html-page-wafl.html}\n" =>
            qr{href="/data/workspaces/admin/attachments/formatter_test_for_html_page_wafl:\S+?/html-page-wafl.html},
            qr{\Qhtml-page-wafl.html;as_page=1\E},
          ],
          [ "{html-page no-such-page.html}\n" =>
            qr{\Qno-such-page.html\E},
            qr{(?!href)},
          ],
        );

    run_tests( $page, $_ ) for @tests;
}

{
    my $page = $hub->pages->new_from_name('Another html-page wafl test page');

    $page->metadata->Subject('Another html-page wafl test page');
    $page->metadata->update( user => $hub->current_user );
    $page->content('foo');
    $page->store( user => $hub->current_user );

    my @tests =
        ( [ "{html-page [Formatter Test for html-page wafl] html-page-wafl.html}\n" =>
            qr{href="/data/workspaces/admin/attachments/formatter_test_for_html_page_wafl:\S+?/html-page-wafl.html},
            qr{\Qhtml-page-wafl.html;as_page=1\E},
          ],
        );

    run_tests( $page, $_ ) for @tests;
}

sub run_tests {
    my ($page, $tests) = @_;

    # XXX without this the existence of the attachment to the page
    # is not correct, and the test fails, so there appears to be
    # an issue with a hidden dependency on current
    $page->hub->pages->current($page);

    my $text = shift @$tests;
    $page->content($text);
    $page->store(user => $hub->current_user);

    my $html = $page->to_html;

    for my $re (@$tests) {
        my $name = $text;
        chomp $name;

        $name .= " =~ $re";

        like( $html, $re, $name );
    }
}
