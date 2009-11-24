(function($){

Socialtext = Socialtext || {};
Socialtext.Base = function() {};

Socialtext.Base.prototype = {
    errorCallback: function(callback) {
        return function(xhr, textStatus, errorThrown) {
            var err = xhr ? xhr.responseText : errorThrown;
            if (!callback) return alert(err);
            callback({ error: err });
        };
    },

    successCallback: function(callback) {
        return function(data) { callback({ data: data }) };
    }
}

})(jQuery);
