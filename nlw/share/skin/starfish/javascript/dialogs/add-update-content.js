var ST = window.ST = window.ST || {};
(function ($) {

ST.AddUpdateContent = function () {};
var proto = ST.AddUpdateContent.prototype = new ST.WidgetsLightbox;

proto.showLightbox = function (gallery_id, gadget_id, src, hasXml) {
    this.gallery_id = gallery_id;
    this.gadget_id = gadget_id;
    this.update = gadget_id ? true : false;

    $.showLightbox({
        html: this.process('add-update-content.tt2', {
            update: this.update,
            gadget_id: gadget_id,
            src: /^urn:/.test(src) ? null : src,
            hasXml: hasXml
        }),
        close: '#add-update-content-lightbox .close'
    });

    this.setup();
};

proto.setup = function () {
    var self = this;
    var lightbox = $('#add-update-content-lightbox');

    // Select the appropriate checkbox when either file of url inputs are
    // clicked
    $('input[name=url], input[name=file], input[name=editor]', lightbox)
        .click(function() {
            var name = $(this).attr('name');
            $('input[name=method][value=' + name + ']', lightbox).click();
        });

    $('form', lightbox).submit(function() {
        if ($('input[value=editor]', lightbox).is(':checked')) {
            var url = '/st/widget?account_id=' + self.gallery_id
            if (self.gadget_id) url += '&widget_id=' + self.gadget_id;
            window.location = url;
            return false;
        }
    });

    $('.submit', lightbox).click(function() {
        self.addGadget();
        return false;
    });
};

proto.error = function (error, callback) {
    error = '<pre class="wrap">' + error + '</pre>';
    return ST.WidgetsLightbox.prototype.error.call(this, error, callback);
}

proto.success = function () {
    var message = this.update
        ? loc('widgets.updated=widget')
        : loc('widgets.added');
    get_lightbox('simple', function () {
        successLightbox(message, function () { location.reload() });
    });
}

proto.addGadget = function (form) {
    var self = this;
    var lightbox = $('#add-update-content-lightbox');
    $('iframe', lightbox).unbind('load').load(function () {
        var doc = this.contentDocument || this.contentWindow.document;
        if (!doc) throw new Error("Can't find iframe");

        var content = $('body', doc).text();
        $.hideLightbox();

        var result;
        try { result = $.secureEvalJSON(content) } catch(e){};

        if (!result) {
            self.error(content);
        }
        else if (result.error) {
            if (result.redirect) {
                self.error(result.error, function () { location.reload() });
            }
            else {
                self.error(result.error);
            }
        }
        else {
            if (self.update) {
                // Already in the gallery
                self.success();
            }
            else {
                self.addGadgetToGallery(result.gadget_id);
            }
        }
    });
    $('form', lightbox).submit();
}

proto.addGadgetToGallery = function (gadget_id) {
    var self = this;
    $.ajax({
        url: '/data/gadgets/gallery/' + self.gallery_id + '/gadgets',
        type: 'POST',
        data: gadget_id,
        success: function() {
            self.success();
        },
        error: function (response) {
            self.error(response.responseText);
        }
    });
};

})(jQuery);
