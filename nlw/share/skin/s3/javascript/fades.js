(function($){

$.fn.fade = function(color, cb) {
    var called = false;
    $(this).addClass('colorFaded').animate(
        { backgroundColor: color },
        function() {
            if (cb) cb();
            cb = null;
        }
    );
}

$.fn.yellowFade = function(cb) {
    $(this).fade('#FFC', cb);
}

$.fn.redFade = function(cb) {
    $(this).fade('#ECAAAA', cb);
}

$.fn.clearFades = function(cb) {
    if ($(this).find('.colorFaded').size()) {
        $(this).find('.colorFaded').fade('white', cb);
    }
    else {
        if (cb) cb();
    }
}

})(jQuery);
