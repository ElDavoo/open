Class('Document.Emitter.HTML(Document.Emitter)', function() {

var proto = this.prototype;
proto.className = 'Document.Emitter.HTML';

proto.begin_node = function(node) {
    var tag = node.type;
    switch (tag) {
        case 'asis': case 'line': return;
        case 'br': case 'hr': {
            this.output += '<'+tag+' />';
            return;
        }
        case 'html': {
            var onload = "if (typeof(ss) != 'undefined' && ss.editor) { var recalc = function () { try { ss.editor.DoPositionCalculations() } catch (e) { setTimeout(recalc, 500) } }; recalc() } if (!window.image_dimension_cache) window.image_dimension_cache = {};window.image_dimension_cache['/data/wafl/Raw%20HTML%20section.%20Edit%20in%20Wiki%20Text%20mode.?uneditable=1'] = [ this.offsetWidth, this.offsetHeight ]; this.style.width = this.offsetWidth + 'px'; this.style.height = this.offsetHeight + 'px'";
            this.output += '<img widget="'+node._html.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/>/, '&gt;')+'" src="/data/wafl/Raw%20HTML%20section.%20Edit%20in%20Wiki%20Text%20mode.?uneditable=1" title="Raw HTML section. Edit in Wiki Text mode." onload="'+onload+'" />';
            return;
        }
        case 'waflparagraph': case 'waflphrase': case 'im': {
            var onload = "if (typeof(ss) != 'undefined' && ss.editor) { var recalc = function () { try { ss.editor.DoPositionCalculations() } catch (e) { setTimeout(recalc, 500) } }; recalc() } if (!window.image_dimension_cache) window.image_dimension_cache = {};window.image_dimension_cache['/data/wafl/"+encodeURIComponent(node._label)+"'] = [ this.offsetWidth, this.offsetHeight ]; this.style.width = this.offsetWidth + 'px'; this.style.height = this.offsetHeight + 'px'";
            this.output += '<img widget="{'+node._wafl.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/>/, '&gt;')+'}" src="/data/wafl/'+encodeURIComponent(node._label)+'" onload="'+onload+'" />';
            return;
        }
        case 'a': case 'wikilink': {
            this.output += '<a href="'+encodeURI(node._href)+'">';
            return;
        }
        case 'file': {
            this.output += '<a title="(network resource)" href="'+encodeURI(node._href)+'">';
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
        case 'asis': case 'br': case 'hr': case 'html': case 'waflparagraph': case 'waflphrase': case 'im': return;
        case 'line': {
            this.output += '<br />';
            return;
        }
        case 'file': case 'wikilink': {
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
    this.output += text
        .replace(/&/g, '&amp;')
        .replace(/>/g, '&gt;')
        .replace(/</g, '&lt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&apos;');
}

});
