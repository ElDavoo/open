// Port of label_ellipsis.pm
Jemplate.Filter.prototype.filters.label_ellipsis = function(text, length) {
    var ellipsis = '...';
    if (!length) length = 32;
    if (text.length <= length) return text;
    if (0 == length) return ellipsis;

    var new_text = '';

    var parts = text.split(' ');
    if (parts.length == 1) {
        new_text = text.substr(0,length);
    }
    else {
        $.each(parts, function(i, part) {
            if (new_text.length + part.length > length) {
                new_text += part + ' ';
            }
        });
        if (new_text.length == 0) {
            new_text = parts[0].substr(0, length)
        }
        new_text = new_text;
    }

    new_text = new_text.replace(/\s+$/,'');
    new_text += ellipsis;
    return new_text;
};

