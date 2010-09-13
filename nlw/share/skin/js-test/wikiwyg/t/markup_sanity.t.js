var t = new Test.Wikiwyg();

t.filters({
    text: ['wikitext_to_html_js']
});

t.plan(2);

t.run_like('text', 'html');

/*
=== Non-huggy begin-phrase markers should have no effect.
--- text
mmm - 2 degrees between today- tomorrow

--- html
<p>mmm - 2 degrees between today- tomorrow</p>

=== Non-huggy end-phrase markers should have no effect.
--- text
mmm -2 degrees between today - tomorrow

--- html
<p>mmm -2 degrees between today - tomorrow</p>
*/
