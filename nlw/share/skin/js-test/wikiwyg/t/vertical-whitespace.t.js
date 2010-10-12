var t = new Test.Wikiwyg();

var filters = {
    html: ['html_to_wikitext']
};

t.plan(3);
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

=== Vertical whitespace in Firefox (part 1)
--- html
<div class="wiki">1<br><br><br><br>3<br><br><br><br><br>5<br></div>
--- wikitext
1



3




5

=== Vertical whitespace in Firefox (part 2)
--- html
<div class="wiki">
<p>
1<br>
<br>
<br>
<br>
</p>
<p>
3<br>
<br>
<br>
<br>
<br>
</p>
<p>
5</p>
</div>
--- wikitext
1



3




5

*/
