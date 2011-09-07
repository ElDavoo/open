(function ($) {

var activitiesDialog = {
    show: function (opts) {
        this.dialog = socialtext.dialog.createDialog({
            html: socialtext.dialog.process(opts.template, opts),
            title: opts.title,
            params: opts.params
        });

        $.extend({
            callback: $.noop
        }, opts);

        this.bind(opts);
    },

    close: function() {
        if (this.dialog) this.dialog.close();
    },

    showError: function(err) {
        if (this.dialog) this.dialog.find('.error').text(err);
    },

    bind: function(opts) {
        var self = this;
        var dialog = self.dialog;

        // Add Attachment popup
        dialog.find('.attachmentPopup form').submit(function() {
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
                }
            });
        });

        // Add Video Popup
        if (dialog.find('.videoPopup').size()) {
            self.startCheckingVideoURL();
        }
        dialog.find('.videoPopup form').submit(function() {
            if (dialog.find('.submit').is(':hidden')) return;
            var url = dialog.find('.video_url').val() || '';
            var title = dialog.find('.video_title').val() || '';

            if (opts.callback(url, title) === false) {
                // cancellable by returning false
                dialog.find('.error')
                    .text(loc("error.invalid-video-link"))
                    .show();
                dialog.find('.video_url').focus();
            }
            else {
                clearInterval(self._intervalId);
                dialog.close();
            }
            return false;
        });

        // Show Video/Image popup
        if (opts.params.video) {
            dialog.disable();
            if (opts.params.video) {
                $.ajax({
                    method: 'GET',
                    dataType: 'text',
                    url: '/?action=get_video_html;autoplay=1;width='
                        + opts.params.video.width
                        + ';video_url=' + encodeURIComponent(opts.params.url),
                    success: function(html) {
                        dialog.enable();
                        dialog.find('.video').html(html);
                    }
                });
            }
        }

        // All
        dialog.find('.submit').click(function() {
            $(this).parents('form:first').submit();
            return false;
        });
    },

    startCheckingVideoURL: function(url) {
        var $url = this.dialog.find('.video_url');
        var $done = this.dialog.find('.submit');
        var $title = this.dialog.find('.video_title');

        var previousURL = $url.val() || null;
        var loading = false;
        var queued = false;

        self._intervalId = setInterval(function (){
            var url = $url.val();
            if (!/^[-+.\w]+:\/\/[^\/]+\//.test(url)) {
                $title.val('');
                url = null;
                $done.hide();
            }
            if (url == previousURL) return;
            previousURL = url;
            if (loading) { queued = true; return }
            queued = false;
            if (!url) return;
            loading = true;
            $title
                .val(loc('activities.loading-video'))
                .attr('disabled', true);

            $done.hide();

            jQuery.ajax({
                type: 'get',
                async: true,
                url: '/',
                dataType: 'json',
                data: {
                    action: 'check_video_url',
                    video_url: url.replace(/^<|>$/g, '')
                },
                success: function(data) {
                    loading = false;
                    if (queued) { return; }
                    if (data.title) {
                        $title
                            .val(data.title)
                            .attr('disabled', false)
                            .attr('title', '');
                        $done.show();
                    }
                    else if (data.error) {
                        $title.val(data.error)
                            .attr('disabled', true)
                            .attr('title', data.error);
                    }
                }
            });
        }, 500);
    }
}

socialtext.dialog.register('activities', function(opts) {
    activitiesDialog.show(opts);
});

})(jQuery);
