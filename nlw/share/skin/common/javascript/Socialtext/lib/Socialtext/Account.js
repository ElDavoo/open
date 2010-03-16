(function($){

Socialtext = Socialtext || {};
Socialtext.Account = function(params) {
    $.extend(this, params);
};

Socialtext.Account.prototype = new Socialtext.Base();

$.extend(Socialtext.Account.prototype, {
    url: function(rest) {
        if (!this.account_name)
            throw new Error(loc("Account name is required"));
        if (!rest) rest = '';
        return '/data/accounts/' + this.account_name + rest;
    },

    addUser: function(user, callback) {
        var self = this;
        if (!user.user_id) throw new Error(loc("user_id is required"));
        $.ajax({
            url: this.url('/users'),
            type: 'post',
            contentType: 'application/json',
            data: $.toJSON({ user_id: user.user_id }),
            success: this.successCallback(callback),
            error: this.errorCallback(callback)
        });
    },

    updateSignalsPrefs: function(prefs, callback) {
        var self = this;
        self.updatePluginPrefs('signals', prefs, callback);
    },

    // Generic
    updatePluginPrefs: function(plugin, prefs, callback) {
        var self = this;
        $.ajax({
            url: this.url('/plugins/' + plugin + '/preferences'),
            type: 'put',
            contentType: 'application/json',
            data: $.toJSON(prefs),
            success: this.successCallback(callback),
            error: this.errorCallback(callback),
        });
    }
});

})(jQuery);
