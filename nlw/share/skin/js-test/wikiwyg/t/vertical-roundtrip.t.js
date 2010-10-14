var t = new Test.Wikiwyg();

t.plan(15);
t.run_roundtrip('wikitext');

/*
=== Whitespace around HR (1)
--- wikitext
white
␤----
␤space

=== Whitespace around HR (2)
--- wikitext
white
␤␤----
␤␤space

=== Whitespace around HR (3)
--- wikitext
white
␤␤␤----
␤␤␤space

=== Whitespace around UL (1)
--- wikitext
white
␤* li␤* li
␤space

=== Whitespace around UL (2)
--- wikitext
white
␤␤* li␤* li
␤␤space

=== Whitespace around UL (3)
--- wikitext
white
␤␤␤* li␤* li
␤␤␤space

=== Whitespace around OL (1)
--- wikitext
white
␤# li␤# li
␤space

=== Whitespace around OL (2)
--- wikitext
white
␤␤# li␤# li
␤␤space

=== Whitespace around OL (3)
--- wikitext
white
␤␤␤# li␤# li
␤␤␤space

=== Whitespace around H1 (1)
--- wikitext
white
␤^ H1
␤space

=== Whitespace around H1 (2)
--- wikitext
white
␤␤^ H1
␤␤space

=== Whitespace around H1 (3)
--- wikitext
white
␤␤␤^ H1
␤␤␤space

=== Whitespace between lists (1)
--- wikitext
white
␤* li␤* li
␤# li␤# li
␤space

=== Whitespace between lists (2)
--- wikitext
white
␤␤* li␤* li
␤␤# li␤# li
␤␤space

=== Whitespace between lists (3)
--- wikitext
white
␤␤␤* li␤* li
␤␤␤# li␤# li
␤␤␤space

*/
