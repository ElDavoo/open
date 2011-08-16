var ST = window.ST = window.ST || {};
(function ($) {

ST.ConfirmLightbox = function () {};
var proto = ST.ConfirmLightbox.prototype = new ST.WidgetsLightbox;

proto.showLightbox = function (opts) {
    $.showLightbox({
        html: this.process('confirm.tt2'),
        close: '#confirm-lightbox .close',
        callback: function () {
            $('#confirm-lightbox .yes').unbind('click').click(function() {
                opts.onConfirm();
                return false;
            });
        }
    });
};

})(jQuery);
