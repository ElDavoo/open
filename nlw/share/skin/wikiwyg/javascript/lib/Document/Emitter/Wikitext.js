proto = new Subclass('Document.Emitter.Wikitext');

// XXX - Subclass not calling init for some reason....
proto.init = function() {
    this.output = '';
}

//------------------------------------------------------------------------------
// Public - textview = emitter.emit(bytecode);
//------------------------------------------------------------------------------
proto.emit = function(bytecode) {
    this.input = bytecode;
    this.output = '';
    this.emit_blocks('top');
    return this.output;
}

//------------------------------------------------------------------------------
// Scan the bytecode for looking for the blocks this unit contains in order.
// Call each block's handler and append output. Insert appropriate intervening
// whitespace. Continue until input is eaten.
//------------------------------------------------------------------------------
proto.emit_blocks = function(container_type) {
    var types = Document.contains[container_type];
    var prev = 'start';
    while (this.input.length) {
        var length = this.input.length;
        for (var i = 0; i < types.length; i++) {
            var type = types[i];
            var re = new RegExp( '^\\+' + type + '(.*)\\n([\\s\\S]*?\\n)-' + type + '\\n');
            if (! this.input.match(re)) continue;
            this.input = this.input.substr(RegExp.lastMatch.length);
            var func = 'handle_' + type;
            if (! this[func])
                throw(func + ' is not defined');
            var output = this[func](RegExp.$2, RegExp.$1);

            this.add_whitespace(prev, type);
            prev = type;
            this.output += output;
        }
        if (this.input.length >= length)
            throw(this.reduction_error());
    }
    return this.output;
}

//------------------------------------------------------------------------------
// Just scan the bytecode one element at a time and handle each one until all
// the input is eaten.
//------------------------------------------------------------------------------
proto.emit_phrases = function() {
    while (this.input.length) {
        if (this.input.match(/^ (.*(?:\n .*)*)\n/)) {
            this.input = this.input.substr(RegExp.lastMatch.length);
            this.output += this.handle_text(RegExp.$1);
        }
        else if (this.input.match(/^\+(\w+)(.*)\n([\s\S]*?\n)-\1\n/)) {
            this.input = this.input.substr(RegExp.lastMatch.length);
            var func = "handle_" + RegExp.$1;
            if (! this[func])
                throw(func + ' is not defined');
            this.output += this[func](RegExp.$3, RegExp.$2);
        }
        else {
            throw(this.reduction_error());
        }
    }
    return this.output;
}

//------------------------------------------------------------------------------
// Handler functions
//------------------------------------------------------------------------------
proto.handle_text = function(text) {
    return text;
}

proto.handle_h2 = function(text) {
    var emitter = new Document.Emitter.Wikitext();
    emitter.output = '';
    emitter.input = text;
    var output = emitter.emit_phrases();
    return '^^ ' + output + '\n';
}

proto.handle_p = function(text) {
    var emitter = new Document.Emitter.Wikitext();
    emitter.output = '';
    emitter.input = text;
    var output = emitter.emit_phrases();
    output += "\n";
    return output;
}

proto.handle_i = function(text) {
    var emitter = new Document.Emitter.Wikitext();
    emitter.input = text;
    emitter.output = '';
    var output = emitter.emit_phrases();
    return '_' + output + '_';
}

proto.handle_ul = function(text) {
    var emitter = new Document.Emitter.Wikitext();
    emitter.input = text;
    emitter.output = '';
    var output = emitter.emit_blocks('ul');
    return output;
}

proto.handle_li = function(text) {
    var emitter = new Document.Emitter.Wikitext();
    emitter.input = text;
    emitter.output = '';
    var output = emitter.emit_phrases();
    return '* ' + output + '\n';
}

//------------------------------------------------------------------------------
// Helper functions
//
// These are the odds and ends called by the code above.
//------------------------------------------------------------------------------
proto.reduction_error = function() {
    return this.classname + ' reduction error for:\n"' + this.input + '"';
}

proto.add_whitespace = function(prev, curr) {
    this.output += this.whitespace_rules()[prev + '-' + curr] || '';
}

proto.whitespace_rules = function() {
    return {
        'p-p': "\n",
        'h2-p': "\n",
        'p-ul': "\n"
    };
}

