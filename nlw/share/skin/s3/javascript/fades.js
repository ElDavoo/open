(function($){

$.fn.fade = function(color, cb) {
    $(this).addClass('colorFaded').animate({ backgroundColor: color }, cb);
}

$.fn.yellowFade = function(cb) {
    $(this).fade('#FFC', cb);
}

$.fn.redFade = function(cb) {
    $(this).fade('#ECAAAA', cb);
}

$.fn.clearFades = function(cb) {
    if ($(this).find('.colorFaded').size()) {
        $(this).find('.colorFaded').animate({ backgroundColor: 'white' }, cb);
    }
    else {
        if (cb) cb();
    }
}

})(jQuery);
