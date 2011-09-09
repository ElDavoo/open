wiki2html = require('wiki2html')

tests = [
  ["Hello *world*", "<p>Hello <b>world</b></p>"]
  [".code-perl\nMoose\n.code-perl\n", "<p>Hello <b>world</b></p>"]
]

for [wiki, html] in tests
  eq wiki2html(wiki), "#{html}\n", wiki
