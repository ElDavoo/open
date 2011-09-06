(function ($) {

socialtext.dialog.register('simple', function(opts) {
    var dialog = socialtext.dialog.createDialog({
        html: socialtext.dialog.process('simple.tt2', opts),
        title: opts.title
    });
    dialog.find('.close').click(function() {
        if ($.isFunction(opts.onClose)) opts.onClose();
        dialog.close();
        return false;
    });
});

})(jQuery);
