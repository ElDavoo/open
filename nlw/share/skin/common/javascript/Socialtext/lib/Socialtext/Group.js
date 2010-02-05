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
    postArgs: [
        'ldap_dn', 'name', 'account_id', 'description', 'photo_id',
        'workspaces', 'users', 'send_message', 'additional_message',
        'new_workspaces'
    ],
    putArgs: [ 'name', 'account_id', 'description', 'photo_id' ],

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
        var args = type == 'POST' ? this.postArgs : this.putArgs;
        $.each(args, function(i, arg) { if (self[arg]) data[arg] = self[arg] });

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
        var self = this;
        if (self.group_id) {
            var users = {
                users: self.users,
                send_message: self.send_message,
                additional_message: self.additional_message
            };
            var jobs = [
                function(cb) { self.request('PUT', self.url(), cb) },
                function(cb) { self.addMembers(users, cb) },
                function(cb) { self.addToWorkspaces(self.workspaces, cb) },
                function(cb) { self.changeMemberships(self.changedmemberships, cb) },
                function(cb) { self.removeTrash(self.trash, cb) }
            ];
            $.each(self.new_workspaces || [], function(i, info) {
                info.groups = {group_id: self.group_id};
                jobs.push(function(cb) {
                    Socialtext.Workspace.Create(
                        $.extend({ callback: cb }, info)
                    );
                });
            });

            self.runAsynch(jobs, callback);
        }
        else {
            // We still should call changedmemberships after group created for 
            // changing the memberships of newly added users
            self.create(function () {
                self.changeMemberships(self.changedmemberships, callback);
                });
        }
    },

    addMembers: function(data, callback) {
        if (!data.users.length) return callback({});
        this.postItems(this.url('/users'), data, callback);
    },

    changeMemberships: function(memberships, callback) {
        if (!memberships.length) return callback({});
        this.postItems(this.url('/membership'), memberships, callback);
    },

    addToWorkspaces: function(workspaces, callback) {
        if (!workspaces.length) return callback({});
        this.postItems(this.url('/workspaces'), workspaces, callback);
    },

    removeTrash: function(trash, callback) {
        if (!trash.length) return callback({});
        this.postItems(this.url('/trash'), trash, callback);
    },

    postItems: function(url, list, callback) {
        $.ajax({
            url: url,
            type: 'post',
            dataType: 'json',
            contentType: 'application/json',
            data: $.toJSON(list),
            success: function() { if (callback) callback({}) },
            error: this.errorCallback(callback)
        });
    },

    hasMember: function(username, callback) {
        if (!Number(this.group_id)) {
            callback(false);
        }
        else {
            $.ajax({
                url: this.url('/users/' + username),
                type: 'HEAD',
                success: function() { if (callback) callback(true) },
                error:   function() { if (callback) callback(false) }
            });
        }
    },

    getAdmins: function(callback) {
        $.getJSON(this.url('?show_admins=1'), function(data) { 
            var result=[];
            result = $.map(data.admins, function(elem, index) {
                return elem.user_id;
            });
            callback(result);
        });
    }
});

})(jQuery);
