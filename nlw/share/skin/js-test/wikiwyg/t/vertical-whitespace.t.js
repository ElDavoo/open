var t = new Test.Wikiwyg();

var filters = {
    html: ['html_to_wikitext']
};

t.plan(1);
t.filters(filters);
t.run_is('html', 'wikitext');



/* Test
=== Vertical whitespace in Chrome
--- html
<div class="wiki">1</div><div class="wiki"><br></div><div class="wiki"><br></div><div class="wiki"><br></div><div class="wiki">2</div><div class="wiki"><br></div><div class="wiki"><br></div><div class="wiki">3</div>
--- wikitext
1



2


3

*/
