(function($) {

Socialtext = Socialtext || {};
Socialtext.Workspace = function(params) {
    delete params.create;
    $.extend(this, params);
};

Socialtext.Workspace.prototype = new Socialtext.Base();

$.extend(Socialtext.Workspace.prototype, {
    url: function(extra) {
        if (!extra) extra = '';
        return '/data/workspaces/' + this.name + extra
    },
    _splitMemberRoles: function(members) {
        // XXX: We should make /data/workspace/:ws/members so we don't need to
        // split this here
        var roles = { users: [], groups: [] };
        $.each(members, function(i, mem) {
            var role = {};
            if (mem.role_name) role.role_name = mem.role_name;
            if (mem.group_id) role.group_id = mem.group_id;
            if (mem.user_id) role.user_id = mem.user_id;
            if (mem.username) role.username = mem.username;
            if (mem.group_id) {
                roles.groups.push(role);
            }
            else if (mem.user_id || mem.username) {
                roles.users.push(role);
            }
        });
        return roles;
    },
    updateMembers: function(opts) {
        var self = this;
        var members = this._splitMemberRoles(opts.members);
        if (!members.users.length && !members.groups.length) {
            throw new Error("No members specified");
        }
        $.each(members, function(collection, list) {
            if (!list.length) return;
            $.ajax({
                url: self.url('/' + collection),
                type: 'PUT',
                contentType: 'application/json',
                data: $.toJSON(list),
                success: function(data) {
                    if ($.isFunction(opts.callback)) opts.callback();
                },
                error: self.errorCallback(opts.callback)
            });
        });
    },
    addMember: function(member, callback) {
        var collection = member.group_id ? 'groups' : 'users';
        member.rolename = 'member';
        $.ajax({
            url: this.url('/' + collection),
            type: 'POST',
            contentType: 'application/json',
            data: $.toJSON(member),
            success: function(data) {
                if ($.isFunction(callback)) callback();
            },
            error: this.errorCallback(callback)
        });
    },
    removeMembers: function(opts) {
        var data = $.map(opts.members, function(member) {
            var r = {};
            if (member.user_id) r.user_id = member.user_id;
            if (member.group_id) r.group_id = member.group_id;
            if (member.username) r.username = member.username;
            return r;
        });
        $.ajax({
            url: this.url('/trash'),
            type: 'POST',
            contentType: 'application/json',
            data: $.toJSON(data),
            success: function(data) {
                if ($.isFunction(opts.callback)) opts.callback();
            },
            error: this.errorCallback(opts.callback)
        });
    }
});

/**
 * Class Methods
 */
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

Socialtext.Workspace.Create = function(opts) {
    var data = {};
    if (opts.title) data.title = opts.title;
    if (opts.name) data.name = opts.name;
    if (opts.groups) data.groups = opts.groups;

    $.ajax({
        url: '/data/workspaces',
        type: 'POST',
        dataType: 'json',
        contentType: 'application/json',
        data: $.toJSON(data),
        success: function(data) {
            $.extend(self, data);
            if (opts.callback) opts.callback({});
        },
        error: function(xhr, textStatus, errorThrown) {
            var error = xhr ? xhr.responseText : errorThrown;
            opts.callback({ error: error });
        }
    });
}

Socialtext.Workspace.ReservedNames = [
    'account', 'administrate', 'administrator', 'atom', 'attachment',
    'attachments', 'category', 'control', 'console', 'data', 'feed', 'nlw',
    'noauth', 'page', 'recent-changes', 'rss', 'search', 'soap', 'static',
    'st-archive', 'superuser', 'test-selenium', 'workspace', 'wsdl', 'user'
];

Socialtext.Workspace.AssertValidTitle = function (title) {
    if (title.match(/^-/)) {
        throw new Error('Workspace titles cannot begin with a dash');
    }
    if (title.length < 2 || title.length > 64) {
        throw new Error("Workspace titles must be between 2 and 64 characters");
    }
};

Socialtext.Workspace.AssertValidName = function (name) {
    var reserved = Socialtext.Workspace.ReservedNames;
    if ($.inArray(name, reserved) >= 0 || name.match(/^st_/)) {
        throw new Error(name + " is a reserved word");
    }
    if (name.match(/^-/)) {
        throw new Error('Workspace names cannot begin with a dash');
    }
    if (!name.match(/^[a-z0-9_-]{3,30}$/)) {
        throw new Error(
            'Workspace names must consist of 3-30 lowercase letters, ' +
            'numbers, underscores or dashes.'
        );
    }
};

Socialtext.Workspace.TitleToName = function (title) {
    if (title == '')
        return '';
    return encodeURI(
        /* For Safari, the similar regex below doesn't work in Safari */
        title.replace(/[^A-Za-z0-9_+]+/g, '-')
             .replace(/[^A-Za-z0-9_+\u00C0-\u00FF]+/g, '-')
             .substr(0,30)
             .toLocaleLowerCase()
    );
};

Socialtext.Workspace.CheckExists = function (name, callback) {
    $.ajax({
        url: '/data/workspaces/' + name,
        type: 'get',
        dataType: 'json',
        complete: function(xhr) {
            if (xhr.status == 200) {
                callback(true);
            }
            else if (xhr.status == 404) {
                callback(false);
            }
            else {
                throw new Error("Error checking for workspace existence");
            }
        }
    });
};

})(jQuery);
