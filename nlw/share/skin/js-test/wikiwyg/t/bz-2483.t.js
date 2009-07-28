var t = new Test.Wikiwyg();

t.filters({
    html: ['html_to_wikitext']
});

t.plan(1);
t.run_is('html', 'text');

/* Test
=== IE: &nbsp incorrectly parsed as literal "nbsp" when inside anchor text
--- html
<div class="wiki"><a href="http://example.com/">Foo &nbsp; Bar &apos; Baz</a></div>
--- text
"Foo Bar ' Baz"<http://example.com/>

*/
