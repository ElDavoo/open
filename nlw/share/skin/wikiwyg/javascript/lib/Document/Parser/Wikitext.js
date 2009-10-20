Class('Document.Parser.Wikitext(Document.Parser)', function() {

var proto = this.prototype;
proto.className = 'Document.Parser.Wikitext';

proto.init = function() {}

proto.create_grammar = function() {
    // Block TODO: wafl_block, blockquote, wafl_p, li/ul/ol
    var all_blocks = ['pre', 'hr', 'hx', 'ul', 'ol', 'p', 'empty', 'else'];

    // Phrase TODO: wafl_phrase, wikilink, im
    var all_phrases = ['asis', 'tt', 'b', 'i', 'del', 'a', 'file', 'mail']; // "a" includes "hyper" and "b_hyper"

    var re_huggy = function(brace1, brace2) {
        brace2 = '\\' + (brace2 || brace1);
        brace1 = '\\' + brace1;
        return {
            match: new RegExp('(?:^|[^'+brace1+'\\w])('+brace1+'(?=\\S)(?!'+brace2+')(.*?)'+brace2+'(?=[^'+brace2+'\\w]|$))'),
            phrases: (brace1 == '\\`') ? null : all_phrases,
            lookbehind: true
        };
    };

    var re_list = function(bullet, filter_out) {
        var exclusion = new RegExp('(^|\n)' + filter_out + '\ *', 'g');
        return {
            match: new RegExp(
                "^(" + bullet + "+\ .*\n" +
                "(?:[\*\-\+\#]+\ .*\n)*" +
                ")(?:\s*\n)?"
            ),
            blocks: ['ul', 'ol', 'subl', 'li'],
            filter: function(node) {
                return node.text.replace(exclusion, '$1');
            }
        };
    };

    return {
        _all_blocks: all_blocks,
        _all_phrases: all_phrases,
        top: { blocks: all_blocks },
        ol: re_list('#', '[*#]'),
        ul: re_list('[-+*]', '[-+*#]'),
        subl: {
            type: 'li',
            match: /^((.*)\n[*#]+\ .*\n(?:[*#]+\ .*\n)*)(?:\s*\n)?/,
            blocks: ['ul', 'ol', 'li2']
        },
        li: {
            match: /(.*)\n/,
            phrases: all_phrases
        },
        li2: {
            type: '', // Do not emit begin/end node; just reparse
            match: /(.*)\n/,
            phrases: all_phrases
        },
        pre: { match: /^\.pre\ *\n((?:.*\n)*?)\.pre\ *\n(?:\s*\n)?/ },
        hr: { match: /^--+(?:\s*\n)?/ },
        hx: {
            match: /^((\^+) *(.*?)(\s+=+)?\s*?\n+)/,
            phrases: all_phrases,
            filter: function(node) {
                node.type = 'h' + node['1'].length;
                return node['2'];
            }
        },
        p: {
            match: /^((?:(?!(?:(?:\^+|\#+|\*+|\-+) |\>|\.\w+\s*\n|\{[^\}]+\}\s*\n)).*\S.*\n)+(?:(?=^|\n)\s*\n)*)/,
            phrases: all_phrases,
            filter: function(node) { return node.text.replace(/\n$/, '') },
        },
        empty: {
            match: /^(\s*\n)/,
            filter: function(node) { node.type = '' }
        },
        'else': {
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
                node._function = node['2'];
                node._options = node['3']
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
                node._href = node['2'];
                return(node['1'] || node['2']);
            }
        },
        */
        a: {
            match: /((?:"([^"]*)"\s*)?<?((?:http|https|ftp|irc|file):(?:\/\/)?[\;\/\?\:\@\&\=\+\$\,\[\]\#A-Za-z0-9\-\_\.\!\~\*\'\(\)]+[A-Za-z0-9\/#])>?)/,
            filter: function(node) {
                // console.log(node);
                node._href = node['2'];
                return(node['1'] || node['2']);
            }
        },
        file: {
            match: /((?:"([^"]*)")?<(\\\\[^\s\>\)]+)>)/,
            filter: function(node) {
                var href = node['2'].replace(/^\\\\/, '');
                node._href = "file://" + href.replace(/\\/g, '/');
                return(node['1'] || href);
            }
        },
        mail: {
            match: /([\w+%\-\.]+@(?:[\w\-]+\.)+[\w\-]+)/,
            filter: function(node) {
                node.type = 'a';
                node._href = "mailto:" + node.text.replace(/%/g, '%25');
            }
        },
        tt: re_huggy('`'), // Special-cased in re_huggy above to disallow subphrases
        b: re_huggy('*'),
        i: re_huggy('_'),
        del: re_huggy('-')
    };
};

});
