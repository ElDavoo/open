proto = new Subclass('Document.Parser.Wikitext');

proto.init = function() {
    this.output = '';
}

proto.parse = function(wikitext) {
    this.input = wikitext;
    this.grammar = this.create_grammar();
    this.parse_blocks('top');
    return this.output;
}

proto.create_grammar = function() {
    var all_blocks = ['pre', 'hx', 'p', 'empty', 'else'];
    var all_phrases = ['asis', 'tt', 'b', 'i', 'del'];
    var re_huggy = function(brace1, brace2) {
        brace2 = '\\' + (brace2 || brace1);
        brace1 = '\\' + brace1;
        return {
            match: new RegExp('(?:^|[^'+brace1+'\\w])('+brace1+'(?=\\S)(?!'+brace2+')(.*?)'+brace2+'(?=[^'+brace2+'\\w]|$))'),
            phrases: all_phrases
        };
    };

    return {
        _all_blocks: all_blocks,
        _all_phrases: all_phrases,
        top: { blocks: all_blocks },
        pre: { match: /^(((?=^|\n)\.pre\ *\n)((?:.*\n)*?)((?=^|\n)\.pre\ *\n)(?:\s*\n)?)/ },
        hx: {
            match: /^((\^+) *(.*?)(\s+=+)?\s*?\n+)/,
            filter: function(node) {
                node.type = 'h' + node['1'].length;
                return( node.text = node['2'] );
            }
        },
        p: {
            match: /^(((?=^|\n)(?!(?:(?:\^+|\#+|\*+|\-+) |\>|\.\w+\s*\n|\{[^\}]+\}\s*\n)).*\S.*\n)+((?=^|\n)\s*\n)*)/,
            phrases: all_phrases,
            filter: function(node) { return node.text.replace(/\n$/, '') },
        },
        empty: {
            match: /^(\s*\n)/,
            filter: function(node) { node.type = '' }
        },
        else: {
            match: /^((.*)\n)/,
            phrases: [],
            filter: function(node) {
                node.type = 'p';
            }
        },
        /*
        waflphrase: {
            match: /(?:^|(?<=[\s\-]))(?:"(.+?)")?\{([\w-]+)(?=[\:\ \}])(?:\s*:)?\s*(.*?)\s*\}(?=[\W_]|$)/,
            filter: function(node) {
                node.attributes.function = node['2'];
                node.attributes.options = node['3']
                return(node['1'] || '');
            }
        },
        */
        asis: {
            match: /(\{\{(.*?)\}\}(\}*))/,
            filter: function(node) {
                node.type = '';
                return(node['1'] + node['2']);
            }
        },
        /*
        wikilink: {
            type: 'a',
            match: /(?:"([^"]*)"\s*)?(?:^|(?<=[_\W]))\[(?=[^\s\[\]])(.*?)\](?=[_\W]|$)/,
            filter: function(node) {
                node.attributes.target = node['2'];
                return(node['1'] || node['2']);
            }
        },
        a: {
            type: 'a',
            match: /(?:"([^"]*)"\s*)?<?((?:http|https|ftp|irc|file):(?://)?[\;\/\?\:\@\&\=\+\$\,\[\]\#A-Za-z0-9\-\_\.\!\~\*\'\(\)]+[A-Za-z0-9\/#])>?/,
            filter: function(node) {
                node.attributes.href = node['2'];
                return(node['1'] || node['2']);
            }
        },
        */
        tt: re_huggy('`'),
        b: re_huggy('*'),
        i: re_huggy('_'),
        del: re_huggy('-')
    };
};

//------------------------------------------------------------------------------
// Parse input into a series of blocks. With each iteration the parser must
// match a block at position 0 of the text, and remove that block from the
// input reparse it further. This continues until there is no input left.
//------------------------------------------------------------------------------
proto.parse_blocks = function(container_type) {
    var types = this.grammar[container_type].blocks; // Document.contains[container_type];
    if (!types) return;
    while (this.input.length) {
        var length = this.input.length;
        for (var i = 0; i < types.length; i++) {
            var type = types[i];
            var matched = this.find_match('matched_block', type);
            if (matched) {
                this.input = this.input.substr(matched.end);
                this.handle_match(type, matched);
                break;
            }
        }
        if (this.input.length >= length)
            throw 'Parser::Wikitext reduction error for:\n' + this.input +
            '\n' + JSON.stringify(this);
    }
    return;
}

proto.handle_match = function(type, match) {
    var grammar = this.grammar[type];
    var parse = grammar.blocks ? 'parse_blocks' : 'parse_phrases';
    // console.log("Subparsing " + parse + '(' + type + '): ');
    // console.log(match);
    this.subparse(parse, match, type, grammar.filter);
}

proto.find_match = function(matched_func, type) {
    var re = this.grammar[type].match;
    if (!re) throw 'no regexp for type: ' + type;
    if (this.input.match(re)) {
        // console.log("Found match " + type + " - " + matched_func);
        var match = this[matched_func].call(this);
        // console.log(match);
        return match;
    }
    return;
};

//------------------------------------------------------------------------------
// This code parses a chunk into interleaved pieces of plain text and
// phrases. It repeatedly tries to match every possible phrase and
// then takes the match closest to the start. Everything before a
// match is written as text. Matched phrases are subparsed according
// to their rules. This continues until the input is all eaten.
//------------------------------------------------------------------------------
proto.parse_phrases = function(container_type) {
    var types = this.grammar[container_type].phrases;
    if (!types) { this.text_node(this.input); return }
    // console.log("INPUT: " + this.input);
    while (this.input.length) {
        var match = null;
        for (var i = 0; i < types.length; i++) {
            var type = types[i];
            var matched = this.find_match('matched_phrase', type);
            if (! matched) continue;

            if (!match || (matched.begin < match.begin)) {
                match = matched;
                match.type = type;
                if (match.begin == 0) break;
            }
        }
        if (!match) {
            // console.log("NO MATCH: " + this.input);
            this.text_node(this.input);
            break;
        }
        if (match.begin != 0) {
            // console.log("MATCH OFFSET:" + this.input + " (" + match.type + ")" + match.begin);
            this.text_node(this.input.substr(0, match.begin));
            }
        this.input = this.input.substr(match.end);
        this.handle_match(match.type, match);
    }
    return;
}

proto.subparse = function(func, match, type, filter) {
    /* The call could cause side effects to the match object. */
    var filtered_text = filter ? filter(match) : null;

    this.begin_node(match.type || type);

    var parser = new Document.Parser.Wikitext();
    parser.input = (filtered_text == null) ? match.text : filtered_text;
    parser.grammar = this.grammar;
    // console.log("SEEDED: (" + type + ")" + parser.input);
    parser[func].call(parser, type);
    this.output += parser.output;
    this.end_node(match.type || type);
}

//------------------------------------------------------------------------------
// Helper functions
//
// These are the odds and ends called by the code above.
//------------------------------------------------------------------------------

proto.matched_block = function(text, end) {
    return {
        'text': (text || RegExp.$1),
        'end': (end || RegExp.$1.length),
        '1': RegExp.$2,
        '2': RegExp.$3,
        '3': RegExp.$4
    };
}

proto.matched_phrase = function() {
    var text = RegExp.$2 || RegExp.$1;
    var begin = this.input.indexOf(RegExp.$1);
    return {
        'text': text,
        'begin': begin,
        'end': (begin + RegExp.$1.length),
        '1': RegExp.$2,
        '2': RegExp.$3,
        '3': RegExp.$4
    };
}

proto.begin_node = function(tag) {
    this.output += '+' + tag + '\n';
    return;
}

proto.end_node = function(tag) {
    this.output += '-' + tag + '\n';
    return;
}

proto.text_node = function(text) {
    text = text.replace(/\n/g, '\n ');
    this.output += ' ' + text + '\n';
    return;
}
