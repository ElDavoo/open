Class('Document.Parser', function() {

var proto = this.prototype;

proto.className = 'Document.Parser';

proto.init = function() {}

proto.parse = function(input, receiver) {
    this.input = input;
    if (receiver) this.receiver = receiver;
    this.receiver.init();
    this.grammar = this.create_grammar();
    this.parse_blocks('top');
    return this.receiver.content();
}

proto.create_grammar = function() {
    throw "Please define create_grammar in a derived class of Document.Parser.";
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
            throw this.classname + ': Reduction error for:\n' + this.input +
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
    if (!types) { this.receiver.text_node(this.input); return }
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
            this.receiver.text_node(this.input);
            break;
        }
        if (match.begin != 0) {
            // console.log("MATCH OFFSET:" + this.input + " (" + match.type + ")" + match.begin);
            this.receiver.text_node(this.input.substr(0, match.begin));
            }
        this.input = this.input.substr(match.end);
        this.handle_match(match.type, match);
    }
    return;
}

proto.subparse = function(func, match, type, filter) {
    /* The call could cause side effects to the match object. */
    var filtered_text = filter ? filter(match) : null;

    match.type = match.type || type;

    this.receiver.begin_node(match);

    var parser = eval('new ' + this.className + '()');

    parser.input = (filtered_text == null) ? match.text : filtered_text;
    parser.grammar = this.grammar;
    parser.receiver = this.receiver.new();
    // console.log("SEEDED: (" + type + ")" + parser.input);
    parser[func].call(parser, type);
    this.receiver.insert(parser.receiver);
    this.receiver.end_node(match);
}

//------------------------------------------------------------------------------
// Helper functions
//
// These are the odds and ends called by the code above.
//------------------------------------------------------------------------------

proto.matched_block = function(text, end) {
    text = text || RegExp.$2 || RegExp.$1;
    return {
        'text': text,
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

});
