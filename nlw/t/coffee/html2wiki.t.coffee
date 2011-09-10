async = require('async')
html2wiki = require('html2wiki')

tests = [
  ["<p>Hello <b>world</b></p>", "Hello *world*"]
  ["<h2>Hello</h2>", "^^ Hello"]
  ["<table>\n<tr><td>Jai guru</td></tr></table>", "| Jai guru |"]
  ["<ul><li>deva<ul><li>aum</li></ul></li></ul>", "* deva\n** aum"]
  ["<ol><li>1<ul><li>1A</li></ul></li><li>2</li></ol>", "# 1\n** 1A\n# 2"]
]

plan tests.length*2

makeStep = ([html, wiki]) ->
  (next) -> html2wiki html, (error, result) ->
    ok not error
    eq result, "#{wiki}\n", html
    next()

steps = (makeStep t for t in tests)
async.series steps, done_testing
