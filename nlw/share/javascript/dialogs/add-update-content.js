(function ($) {

var addContent = {
    onSuccess: $.noop,
    show: function (opts) {
        $.extend(this, opts);
        this.dialog = socialtext.dialog.createDialog({
            html: socialtext.dialog.process('add-update-content.tt2', {
                update: this.gadget_id ? true : false,
                gadget_id: this.gadget_id,
                src: /^urn:/.test(this.src) ? null : this.src,
                hasXml: this.hasXml
            }),
            title: this.gadget_id
                ? loc('widgets.update-widget')
                : loc('widgets.add-widget'),
        });
        this.setup();
        return this.dialog;
    },

    setup: function () {
        var self = this;
        // Select the appropriate checkbox when either file of url inputs are
        // clicked
        self.dialog.find('input[name=url],input[name=file],input[name=editor]')
            .click(function() {
                var name = $(this).attr('name');
                self.dialog.find('input[name=method][value='+name+']').click();
            });

        self.dialog.find('form').submit(function() {
            if (self.dialog.find('input[value=editor]').is(':checked')) {
                var url = '/st/widget?account_id=' + self.account_id;
                if (self.gadget_id) url += '&widget_id=' + self.gadget_id;
                window.location = url;
                return false;
            }
        });

        self.dialog.find('.submit').click(function() {
            self.addGadget();
            return false;
        });
    },

    error: function (error, callback) {
        error = '<pre class="wrap">' + error + '</pre>';
        return this.showError(error, callback);
    },

    success: function () {
        var message = this.gadget_id
            ? loc('widgets.updated=widget')
            : loc('widgets.added');
        get_lightbox('simple', function () {
            successLightbox(message, function () { location.reload() });
        });
    },

    addGadget: function (form) {
        var self = this;
        self.dialog.find('iframe').unbind('load').load(function () {
            var doc = this.contentDocument || this.contentWindow.document;
            if (!doc) throw new Error("Can't find iframe");

            var content = $('body', doc).text();
            self.dialog.close();

            var result;
            try { result = $.secureEvalJSON(content) } catch(e){};

            if (!result) {
                self.showError(content);
            }
            else if (result.error) {
                self.showError(result.error);
            }
            else {
                if (self.gadget_id) {
                    self.onSuccess();
                }
                else {
                    self.addGadgetToGallery(result.gadget_id);
                }
            }
        });
        self.dialog.find('form').submit();
    },

    addGadgetToGallery: function (gadget_id) {
        var self = this;
        $.ajax({
            url: '/data/accounts/' + self.account_id + '/gadgets/' + gadget_id,
            type: 'PUT',
            success: function() {
                self.onSuccess();
            },
            error: function (response) {
                self.showError(response.responseText);
            }
        });
    }
};

socialtext.dialog.register('add-update-content', function(args) {
    addContent.show(args);
});

})(jQuery);
