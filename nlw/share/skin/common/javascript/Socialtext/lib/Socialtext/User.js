(function($){

Socialtext = Socialtext || {};

Socialtext.User = function(params) {
    $.extend(this, params);
};

Socialtext.User.prototype = new Socialtext.Base();

$.extend(Socialtext.User.prototype, {
    create: function() {
        throw new Error("Unimplemented");
    },

    url: function() {
        if (!this.username) throw new Error("No username");
        return '/data/users/' + this.username;
    },

    setPrimaryAccountId: function(id, callback) {
        var self = this;
        if (!callback) callback = function(r) { if (r.error) alert(r.error) };
        if (!id) throw new Error("ID required");
        $.ajax({
            url: this.url(),
            type: 'put',
            contentType: 'application/json',
            data: $.toJSON({
                primary_account_id: id
            }),
            success: this.successCallback(callback),
            error: this.errorCallback(callback)
        });
    }
});

})(jQuery);
