(function($) {

Socialtext = Socialtext || {};
Socialtext.Workspace = function(params) {
    $.extend(this, params);
};

Socialtext.Workspace.prototype = new Socialtext.Base();

$.extend(Socialtext.Workspace.prototype, {});

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
