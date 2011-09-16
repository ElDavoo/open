wiki2html = require('wiki2html')

tests = [
  ["Hello *world*", "<p>Hello <b>world</b></p>\n"]
  [".code-perl\nMoose\n.code-perl\n", """
<img alt="st-widget-.code-perl
Moose
.code-perl" src="/data/wafl/code-perl%20section.%20Edit%20in%20Wiki%20Text%20mode." title="code-perl section. Edit in Wiki Text mode." class="st-widget" />
  """]
  ["{user: q@q.q}", """
<img alt="st-widget-{user: q@q.q}" src="/data/wafl/user%3A%20q%40q.q" class="st-widget st-inline-widget" />
  """]
  ["{{Unformatted}}", """
<p><img alt="st-widget-{{Unformatted}}" src="/data/wafl/Unformatted" class="st-widget st-inline-widget" /></p>\n
  """]
  ["|| sort:on border:off\n| Cell |", """
<table style="border-collapse: collapse" options="sort:on border:off" class="formatter_table sort borderless"><tr>\n<td>Cell</td>\n</tr>\n</table><p></p>\n
  """]
  ["\"label\"{link: [page]}", """
<img alt="st-widget-&#34;label&#34;{link: [page]}" src="/data/wafl/label" class="st-widget st-inline-widget" />
  """]
  ["text \"label\"{link: [page]}", """
<p>text <img alt="st-widget-&#34;label&#34;{link: [page]}" src="/data/wafl/label" class="st-widget st-inline-widget" /></p>\n
  """]
  ["| multi\nline |", """
<table style="border-collapse: collapse" options="" class="formatter_table" border="1"><tr>\n<td><p>multi<br />\nline</p>\n</td>\n</tr>\n</table><p></p>\n
  """]
  ["""
| x | y z
[w] |
  """, """
<table style="border-collapse: collapse" options="" class="formatter_table" border="1"><tr>
<td>x</td>
<td><p>y z<br />
<a href="w">w</a></p>
</td>
</tr>
</table><p></p>\n
  """]
  ["""
"Test" <mailto:foo@bar.org>
  """, """
<p><a href="mailto:foo@bar.org">Test</a></p>\n
"""
  ]
]

for [wiki, html] in tests
  eq wiki2html(wiki), html
