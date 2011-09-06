async = require('async')
html2wiki = require('html2wiki')

tests = [
  ["<p>Hello <b>world</b></p>", "Hello *world*\n"]
  ["<h2>Hello</h2>", "^^ Hello\n"]
  ["<table>\n<tr><td>Jai guru</td></tr></table>", "| Jai guru |\n"]
]

plan tests.length

makeStep = ([html, wiki]) ->
  (next) -> html2wiki html, (result) ->
    eq result, wiki; next()

steps = (makeStep t for t in tests)
async.series steps, done_testing
