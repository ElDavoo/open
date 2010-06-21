#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 9;
use YAML;

fixtures(qw( admin ));

###############################################################################
# TEST: ability to convert a page to HTML, from "admin" Workspace.
convert_page_to_html: {
    my $hub  = new_hub('admin');
    my $file = $hub->pdf_export->_create_html_file('Conversations');
    ok $file, 'Got file from converting wikipage to HTML';
    ok -s $file, '... which is not an empty file';
}

###############################################################################
# TEST: multi-page export, from "admin" Workspace.
multi_page_export: {
    my @pages = ('Conversations', 'Start Here', 'Meeting agendas');
    my $hub   = new_hub('admin');
    my $pdf;
    $hub->pdf_export->multi_page_export(\@pages, \$pdf);
    looks_like_pdf_ok $pdf, 'Multi-page export looks like PDF';
}

###############################################################################
# TEST: create some wikipages, and convert them to PDF
export_to_pdf: {
    my $hub   = create_test_hub();
    my @cases = Load(join '', <DATA>);

    foreach my $case (@cases) {
        my ($content, $title) = @{$case};
        my $page = Socialtext::Page->new(hub => $hub)->create(
            creator => $hub->current_user,
            title   => $title,
            content => $content,
        );
        ok $page, "Created test page: $title";

        my $pdf;
        $hub->pdf_export->multi_page_export([ $page->name ], \$pdf);
        looks_like_pdf_ok $pdf, '... results look like a PDF';
    }
}



__DATA__
---
- |
    | 1a | 1b |
    | 2a | *2b* |

    hello
- Table and paragraph
---
- '* one'
- Unordered list
---
- |
    .html
    <ul>
    <li>one</li>
    </ul>
    .html
- UL in html block
