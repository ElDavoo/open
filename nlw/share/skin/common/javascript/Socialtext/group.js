(function($){

Socialtext = Socialtext || {};
Socialtext.Group = function(params) {
    $.extend(this, params);
};

Socialtext.Group.GetDrivers = function(callback) {
    $.getJSON('/data/group_drivers', callback);
};

Socialtext.Group.GetDriverGroups = function(driver_key, callback) {
    var url = '/data/group_drivers/' + driver_key + '/groups';
    $.getJSON(url, callback);
};

Socialtext.Group.prototype = new Socialtext.Base();

$.extend(Socialtext.Group.prototype, {
    url: function(rest) {
        rest = rest || '';
        return '/data/groups/' + this.group_id + rest;
    },

    create: function(callback) {
        var self = this;
        if (!this.name && !this.ldap_dn) {
            throw new Error(loc("LDAP DN or group name required"));
        }

        var data = {};
        if (this.ldap_dn) data.ldap_dn = this.ldap_dn;
        if (this.name) data.name = this.name;
        if (this.account_id) data.account_id = this.account_id;
        if (this.description) data.description = this.description;

        $.ajax({
            url: '/data/groups',
            type: 'post',
            dataType: 'json',
            contentType: 'application/json',
            data: $.toJSON(data),
            success: function(data) {
                $.extend(self, data);
                if (callback) callback({});
            },
            error: this.errorCallback(callback)
        });
    }
});

})(jQuery);
