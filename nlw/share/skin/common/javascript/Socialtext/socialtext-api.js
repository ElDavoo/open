// BEGIN base.js
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
// BEGIN account.js
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
    }
});

})(jQuery);
// BEGIN group.js
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
// BEGIN useraccountrole.js
(function($){

Socialtext = Socialtext || {};

Socialtext.UserAccountRole = function(params) {
    $.extend(this, params);
};

Socialtext.UserAccountRole.prototype = new Socialtext.Base();

$.extend(Socialtext.UserAccountRole.prototype, {
    url: function() {
        if (!this.username) throw new Error(loc("username is required"));
        if (!this.account_name)
            throw new Error(loc("account_name is required"));

        return '/data/accounts/' + this.account_name +
               '/users/' + this.username;
    },

    remove: function(callback) {
        if (!callback) callback = function(r) { if (r.error) alert(r.error) };
        $.ajax({
            url: this.url(),
            type: 'delete',
            success: this.successCallback(callback),
            error: this.errorCallback(callback)
        });
    },

    toString: function() {
        var roles = [];
        if (this.is_primary != undefined) {
            if (this.is_primary) {
                roles.push(loc("Primary Account"));
            }
            else {
                roles.push(loc("Member of Account"));
            }
        }
        if (this.via_workspace) {
            roles.push(loc(
                "Via [quant,_1,Workspace]: [_2]",
                this.via_workspace.length,
                $.map(this.via_workspace, function (w) {
                    var href = "/nlw/control/account/" + w.workspace_id;
                    return '<a href="' + href + '">' + w.name + '</a>';
                }).join(", ")
            ));
        }
        if (this.via_group) {
            roles.push(loc(
                "Via [quant,_1,Group]: [_2]",
                this.via_group.length,
                $.map(this.via_group, function (g) {
                    var href = "/nlw/control/group/" + g.group_id;
                    return '<a href="' + href + '">' + g.name + '</a>';
                }).join(", ")
            ));
        }
        return roles.join(', ');
    }
});

})(jQuery);
// BEGIN user.js
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
// BEGIN workspace.js
(function($) {

Socialtext = Socialtext || {};
Socialtext.Workspace = function(params) {
    $.extend(this, params);
};

Socialtext.Workspace.prototype = new Socialtext.Base();

$.extend(Socialtext.Workspace.prototype, {});

Socialtext.Workspace.All = function(callback) {
    $.ajax({
        url: '/data/workspaces',
        type: 'get',
        dataType: 'json',
        success: function(data) {
            var workspaces = [];
            $.each(data, function(i, w) {
                workspaces.push( new Socialtext.Workspace(w) );
            });
            callback({ data: workspaces });
        },
        error: function(xhr, textStatus, errorThrown) {
            var error = xhr ? xhr.responseText : errorThrown;
            callback({ error: error });
        }
    });
};

})(jQuery);
