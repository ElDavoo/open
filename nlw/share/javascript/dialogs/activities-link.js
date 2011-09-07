(function ($) {

var linkDialog = {
    show: function (opts) {
        this.dialog = socialtext.dialog.createDialog({
            html: socialtext.dialog.process('activities-link.tt2', opts),
            title: opts.title,
            params: opts.params
        });

        $.extend({
            callback: $.noop
        }, opts);

        this.bind(opts);
    },

    bind: function(opts) {
        var self = this;
        var dialog = self.dialog;

        dialog.find(".wiki-option").change(function() {
            // Disable everything
            dialog.find(".webField, .wikiField")
                .attr('disabled', 'disabled')
                .addClass('disabled');

            // Re-enable valid inputs
            dialog.find(".wiki-link-label, .wiki-link-workspace")
                .attr('disabled', '')
                .removeClass('disabled');

            if (dialog.find('.wiki-link-workspace').val()) {
                dialog.find(".wiki-link-page, .wiki-link-section")
                    .attr('disabled', '')
                    .removeClass('disabled');
            }
        });

        dialog.find(".web-option").change(function() {
            dialog.find(".wikiField")
                .attr('disabled', 'disabled')
                .addClass('disabled');
            dialog.find(".webField")
                    .attr('disabled', '')
                .removeClass('disabled');
        });

        dialog.find(".wiki-option").change();

        dialog.find('.wiki-link-workspace').lookahead({
            filterName: 'title_filter', 
            url: '/data/workspaces',
            params: { order: 'title' },
            linkText: function (i) { 
                return [ i.title + ' (' + i.name + ')', i.name ]; 
            },
            onAccept: function(id, item) {
                dialog.find('.wiki-option').click();
            }
        });

        dialog.find('.wiki-link-page').lookahead({
            url: function() {
                var ws = dialog.find('.wiki-link-workspace').val();
                if (!ws) return false;
                return '/data/workspaces/' + ws + '/pages';
            },
            params: { minimal_pages: 1 },
            linkText: function (i) { return i.name },
            onError: {
                404: function () {
                    return(loc('error.no-wiki-on-server=wiki', workspace));
                }
            }
        });

        dialog.find('form').submit(function() {
            if (dialog.find('.wiki-option').is(':checked')) {
                opts.callback(dialog, {
                    workspace: dialog.find('.wiki-link-workspace').val(),
                    page: dialog.find('.wiki-link-page').val(),
                    label: dialog.find('.wiki-link-label').val(),
                    section: dialog.find('.wiki-link-section').val(),
                });
            }
            else if (dialog.find('.web-option').is(':checked')) {
                opts.callback(dialog, {
                    label: dialog.find('.web-link-label').val(),
                    destination: dialog.find('.web-link-destination').val(),
                });
            }
            else {
                throw new Error('Only web and wiki links supported');
            }
            return false;
        });

        dialog.find('.submit').click(function() {
            $(this).parents('form:first').submit();
            return false;
        });
    }
}

socialtext.dialog.register('activities-link', function(opts) {
    linkDialog.show(opts);
});

})(jQuery);
