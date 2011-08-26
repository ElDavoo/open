(function ($) {

var addContent = {
    opts: {},
    show: function (opts) {
        this.opts = opts;
        this.dialog = socialtext.dialog.createDialog({
            html: socialtext.dialog.process('add-update-content.tt2', {
                update: this.opts.gadget_id ? true : false,
                gadget_id: this.opts.gadget_id,
                src: /^urn:/.test(this.opts.src) ? null : this.opts.src,
                hasXml: this.opts.hasXml
            }),
            title: this.opts.gadget_id
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
                var url = '/st/widget?account_id=' + self.opts.account_id;
                if (self.opts.gadget_id)
                    url += '&widget_id=' + self.opts.gadget_id;
                window.location = url;
                return false;
            }
        });

        self.dialog.find('.submit').click(function() {
            self.addGadget();
            return false;
        });
    },

    addGadget: function (form) {
        var self = this;
        self.dialog.find('iframe').unbind('load').load(function () {
            var doc = this.contentDocument || this.contentWindow.document;
            if (!doc) throw new Error("Can't find iframe");

            var content = $('body', doc).text();

            var result;
            try { result = $.secureEvalJSON(content) } catch(e){};

            $(this).unbind('load');

            if (!result) {
                socialtext.dialog.showError(content);
            }
            else if (result.error) {
                socialtext.dialog.showError(result.error);
            }
            else {
                if (self.opts.gadget_id) {
                    self.opts.onSuccess();
                    self.dialog.close();
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
            url: '/data/accounts/' + self.opts.account_id
                + '/gadgets/' + gadget_id,
            type: 'PUT',
            success: function() {
                self.opts.onSuccess();
                self.dialog.close();
            },
            error: function (response) {
                socialtext.dialog.showError(response.responseText);
            }
        });
    }
};

socialtext.dialog.register('add-update-content', function(args) {
    addContent.show(args);
});

})(jQuery);
