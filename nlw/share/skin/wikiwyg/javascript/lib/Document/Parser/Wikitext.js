Class('Document.Parser.Wikitext(Document.Parser)', function() {

var proto = this.prototype;
proto.className = 'Document.Parser.Wikitext';

proto.init = function() {}

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

});
