Class('Document.Emitter', function() {

var proto = this.prototype;
proto.className = 'Document.Emitter';

proto.new = function() {
    return eval('new ' + this.className + '()');
}

proto.init = function() {
    this.output = '';
}

proto.content = function() {
    return this.output;
}

proto.insert = function(receiver) {
    this.output += receiver.output;
}

});
