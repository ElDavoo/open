Class('Document.Emitter.HTML(Document.Emitter)', function() {

var proto = this.prototype;
proto.className = 'Document.Emitter.HTML';

proto.begin_node = function(node) {
    var tag = node.type;
    switch (tag) {
        case 'br': case 'hr': {
            this.output += '<'+tag+' />';
            return;
        }
        case 'wikilink': {
            this.output += '<a href="'+encodeURI(node.attributes.target)+'">';
            return;
        }
        case 'ul': case 'ol': case 'table': case 'tr': {
            this.output += '<'+tag+">\n";
            return;
        }
        default: {
            this.output += '<'+tag+'>';
            return;
        }
    }
}

proto.end_node = function(node) {
    var tag = node.type;
    switch (tag) {
        case 'br': case 'hr': {
            return;
        }
        case 'wikilink': {
            this.output += '</a>';
            return;
        }
        default: {
            if (tag.search(/^(?:p|ul|ol|li|h\d|table|tr|td)$/) == 0) {
                this.output += '</'+tag+">\n";
            }
            else {
                this.output += '</'+tag+'>';
            }
            return;
        }
    }
    return;
}

proto.text_node = function(text) {
    this.output += text;
}


});
