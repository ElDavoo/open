async = require('async')
html2wiki = require('html2wiki')

tests = [
  ["<p>Hello <b>world</b></p>", "Hello *world*"]
  ["<h2>Hello</h2>", "^^ Hello"]
  ["<table>\n<tr><td>Jai guru</td></tr></table>", "| Jai guru |"]
  ["<ul><li>deva<ul><li>aum</li></ul></li></ul>", "* deva\n** aum"]
  ["<ol><li>1<ul><li>1A</li></ul></li><li>2</li></ol>", "# 1\n** 1A\n# 2"]
  ["<span style='font-family:comic sans ms,cursive; font-weight: bold'>Comical</span>", "*Comical*", true]
  ["<span style='font-family:!important;'>Comical</span>", "Comical"]
  ["<u>Comical</u>", "Comical", true]
  ['<a name="foo"></a>', "{section: foo}"]
  ["""
<img alt="st-widget-{user: q@q.q}" src="/data/wafl/user%3A%20q%40q.q" class="st-widget" />
  """, "{user: q@q.q}"]
  ["""
<img alt="st-widget-{{Unformatted}}" src="/data/wafl/Unformatted" class="st-widget" />
  """, "{{Unformatted}}"]
  ["<table><tr><td colspan='1'>Colspan=1</td></tr></table>", "| Colspan=1 |"]
  ["<table><tr><td colspan='2'>Colspan=2</td></tr></table>", "| Colspan=2 |", true]
  ["<table><tr><td rowspan='1'>Rowspan=1</td></tr></table>", "| Rowspan=1 |"]
  ["<table><tr><td rowspan='2'>Rowspan=2</td></tr></table>", "| Rowspan=2 |", true]
]

plan tests.length*2

makeStep = ([html, wiki, isErrorExpected]) ->
  (next) -> html2wiki html, (errors, result) ->
    if isErrorExpected
      ok errors, "HTML parses with error (expected)"
    else
      ok not errors, "HTML parses without error"
    eq result, "#{wiki}\n", "result is correct"
    next()

steps = (makeStep t for t in tests)
async.series steps, done_testing
