(function ($) {

socialtext.dialog.register('confirm', function(opts) {
    if (!$.isFunction(opts.onConfirm)) throw Error('onConfirm required');
    var dialog = socialtext.dialog.createDialog({
        html: socialtext.dialog.process('confirm.tt2', opts),
        title: opts.title
    });
    dialog.find('.yes').click(function() {
        opts.onConfirm();
        dialog.close();
        return false;
    });
    dialog.find('.no').click(function() {
        dialog.close();
        return false;
    });
});

})(jQuery);
