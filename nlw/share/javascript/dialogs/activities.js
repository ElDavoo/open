(function ($) {

var activitiesDialog = {
    show: function (opts) {
        this.dialog = socialtext.dialog.createDialog({
            html: socialtext.dialog.process(opts.template, opts),
            title: opts.title
        });

        if (!$.isFunction(opts.callback))
            throw new Error('callback required');

        this.bind(opts);
    },

    bind: function(opts) {
        var self = this;

        // Attachment popup
        self.dialog.find('.attachmentPopup form').submit(function() {
            self.dialog.disable();

            self.dialog.find('.formtarget').unbind('load').load(function() {
                self.dialog.find('.formtarget').unbind('load');
                // Socialtext Desktop
                var result = this.contentWindow.childSandboxBridge;
                if (!result) {
                    // Activity Widget
                    result = gadgets.json.parse(
                        $(this.contentWindow.document.body).text()
                    );
                }
                if (result && result.status == 'failure') {
                    var msg = result.message || "Error parsing result";
                    self.dialog.find('.error').text(msg).show();
                    self.dialog.enable();
                }
                else if (!result) {
                    var body = this.contentWindow.document.body
                    var msg = body.match(/entity too large/i)
                        ? loc('File size is too large. 50MB maximum, please.')
                        : loc('Error parsing result');
                    self.dialog.find('.error').text(msg).show();
                    self.dialog.enable();
                }
                else {
                    var filename = self.dialog.find('.file').val()
                    filename = filename.replace(/^.*\\|\/:/, '');
                    opts.callback(filename, result);
                    self.dialog.close();
                }
            });
        });

        // All
        self.dialog.find('.submit').click(function() {
            self.dialog.find('form').submit();
            return false;
        });
    }
}

socialtext.dialog.register('activities', function(opts) {
    activitiesDialog.show(opts);
});

})(jQuery);
