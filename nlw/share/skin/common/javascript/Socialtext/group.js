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

    request: function(type, url, callback) {
        var self = this;
        if (!this.name && !this.ldap_dn) {
            throw new Error(loc("LDAP DN or group name required"));
        }

        var data = {};
        if (this.ldap_dn) data.ldap_dn = this.ldap_dn;
        if (this.name) data.name = this.name;
        if (this.account_id) data.account_id = this.account_id;
        if (this.description) data.description = this.description;
        if (this.photo_id) data.photo_id = this.photo_id;

        $.ajax({
            url: url,
            type: type,
            dataType: 'json',
            contentType: 'application/json',
            data: $.toJSON(data),
            success: function(data) {
                $.extend(self, data);
                if (callback) callback({});
            },
            error: this.errorCallback(callback)
        });
    },

    create: function(callback) {
        this.request('POST', '/data/groups', callback);
    },

    save: function(callback) {
        if (this.group_id) {
            this.request('PUT', this.url(), callback);
        }
        else {
            this.create(callback);
        }
    },

    addUsers: function(userList, callback) {
        $.ajax({
            url: this.url('/users'),
            type: 'post',
            dataType: 'json',
            contentType: 'application/json',
            data: $.toJSON(userList),
            success: function() { if (callback) callback({}) },
            error: this.errorCallback(callback)
        });
    },

    hasMember: function(username, callback) {
        if (!this.group_id) {
            callback(false);
        }
        $.ajax({
            url: this.url('/users/' + username),
            type: 'HEAD',
            success: function() { if (callback) callback(true) },
            error:   function() { if (callback) callback(false) }
        });
    }
});

})(jQuery);
