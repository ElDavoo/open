html2wiki = require('html2wiki')
eq html2wiki("<p>Hello <b>world</b></p>"), "Hello *world*\n"
