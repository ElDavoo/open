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

    saveInfo: function(callback) {
        var self = this;
        if (!this.name && !this.ldap_dn) {
            throw new Error(loc("LDAP DN or group name required"));
        }

        var data = {};
        $.each(Socialtext.Group.Args.PUT, function(i, arg) {
            if (self[arg]) data[arg] = self[arg];
        });

        $.ajax({
            url: self.url(),
            type: 'PUT',
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

    save: function(callback) {
        var self = this;
        if (!self.group_id) {
            throw new Error("Can't save group without group_id");
        }

        var users = {
            users: self.users,
            send_message: self.send_message,
            additional_message: self.additional_message
        };
        var jobs = [
            function(cb) { self.saveInfo(cb) },
            function(cb) { self.addMembers(users, cb) },
            function(cb) { self.addToWorkspaces(self.workspaces, cb) },
            function(cb) { self.updateMembers(self.changedmemberships, cb) }
        ];
        $.each(self.new_workspaces || [], function(i, info) {
            info.groups = {group_id: self.group_id};
            jobs.push(function(cb) {
                Socialtext.Workspace.Create(
                    $.extend({ callback: cb }, info)
                );
            });
        });
        $.each(self.trash || [], function(i, info) {
            jobs.push(function(cb) {
                var workspace = new Socialtext.Workspace({
                    name: info.name
                });
                workspace.removeMembers({
                    members: [ { group_id: self.group_id } ],
                    callback: cb
                });
            });
        });

        self.runAsynch(jobs, function() {
            self.call(callback, self);
        });
    },

    // XXX these should be collapsed to one method
    addMembers: function(users, callback) {
        if (!users.length) return callback({});
        this.postItems(this.url('/users'), users, callback);
    },

    call: function(callback, opts) {
        if (typeof(opts) == 'undefined') opts = {};
        if ($.isFunction(callback)) callback(opts);
    },

    updateMembers: function(members, callback) {
        if (!members.length) return this.call(callback);
        this.postItems(this.url('/membership'), members, callback);
    },

    addToWorkspaces: function(workspaces, callback) {
        if (!workspaces.length) return this.call(callback);
        this.postItems(this.url('/workspaces'), workspaces, callback);
    },

    removeMembers: function(trash, callback) {
        if (!trash.length) return this.call(callback);
        this.postItems(this.url('/trash'), trash, callback);
    },

    postItems: function(url, list, callback) {
        var self = this;
        $.ajax({
            url: url,
            type: 'POST',
            dataType: 'json',
            contentType: 'application/json',
            data: $.toJSON(list),
            success: function() { self.call(callback) },
            error: self.errorCallback(callback)
        });
    },

    hasMember: function(username, callback) {
        var self = this;
        if (!Number(self.group_id)) {
            self.call(callback, false);
        }
        else {
            $.ajax({
                url: this.url('/users/' + username),
                type: 'HEAD',
                success: function() { self.call(callback, true) },
                error:   function() { self.call(callback, false) }
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

Socialtext.Group.Args = {
    POST: [
        'ldap_dn', 'name', 'account_id', 'description', 'photo_id',
        'workspaces', 'users', 'send_message', 'additional_message',
        'new_workspaces'
    ],
    PUT: [ 'name', 'account_id', 'description', 'photo_id' ]
};

Socialtext.Group.Create = function(opts, callback) {
    if (!opts.name && !opts.ldap_dn) {
        throw new Error(loc("LDAP DN or group name required"));
    }

    var data = {};
    $.each(Socialtext.Group.Args.POST, function(i, arg) {
        if (opts[arg]) data[arg] = opts[arg]
    });

    $.ajax({
        url: '/data/groups',
        type: 'POST',
        dataType: 'json',
        contentType: 'application/json',
        data: $.toJSON(data),
        success: function(data) {
            var group = new Socialtext.Group(data);
            if (callback) callback(group);
        },
        error: function(xhr, textStatus, errorThrown) {
            var error = xhr ? xhr.responseText : errorThrown;
            if (callback) callback({ error: error });
        }
    });
};

})(jQuery);
