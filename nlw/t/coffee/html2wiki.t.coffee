async = require('async')
html2wiki = require('html2wiki')

tests = [
  ["<p>Hello <b>world</b></p>", "Hello *world*\n"]
  ["<h2>Hello</h2>", "^^ Hello\n"]
  ["<table>\n<tr><td>Jai guru</td></tr></table>", "| Jai guru |\n"]
  ["<ul><li>deva<ul><li>aum</li></ul></li></ul>", "* deva\n** aum\n"]
  ["<ol><li>1<ul><li>1A</li></ul></li><li>2</li></ol>", "# 1\n** 1A\n# 2\n"]
]

plan tests.length

makeStep = ([html, wiki]) ->
  (next) -> html2wiki html, (result) ->
    eq result, wiki; next()

steps = (makeStep t for t in tests)
async.series steps, done_testing
