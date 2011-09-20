(function ($) {

socialtext.dialog.register('activities-add-attachment', function(opts) {
    dialog = socialtext.dialog.createDialog({
        html: socialtext.dialog.process('activities-add-attachment.tt2', opts),
        title: loc('Add Attachment'),
        params: opts.params,
        height: 200,
        buttons: [
            {
                name: loc('do.upload'),
                callback: function() {
                    dialog.find('form').submit();
                }
            },
            {
                name: loc('do.cancel'),
                callback: function() {
                    dialog.close();
                }
            }
        ]
    });

    dialog.find('form').submit(function() {
        dialog.disable();

        dialog.find('.formtarget').unbind('load').load(function() {
            dialog.find('.formtarget').unbind('load');
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
                dialog.find('.error').text(msg).show();
                dialog.enable();
            }
            else if (!result) {
                var body = this.contentWindow.document.body
                var msg = body.match(/entity too large/i)
                    ? loc('File size is too large. 50MB maximum, please.')
                    : loc('Error parsing result');
                dialog.find('.error').text(msg).show();
                dialog.enable();
            }
            else {
                var filename = dialog.find('.file').val()
                filename = filename.replace(/^.*\\|\/:/, '');
                opts.callback(filename, result);
                dialog.close();
            }
        });
    });
});

})(jQuery);
