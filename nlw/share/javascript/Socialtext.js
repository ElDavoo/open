(function($) {

if (typeof(Socialtext) != 'undefined')
    throw new Error ('Socialtext.js must be loaded first!');

Socialtext = function(vars) {
    $.extend(this, vars);

    // TODO this.viewer = new Socialtext.User(this.viewer);
    // TODO this.workspace = new Socialtext.Workspace(this.workspace);
    if (this.page) this.page = new Socialtext.Page(this.page);
}

Socialtext.prototype = {
    info: {
        focus_field: {
            'preferences_settings': 'form > div > input:eq(0)',
            'users_invitation': 'textarea[name="users_new_ids"]',
            'users_settings': 'input[name="first_name"]',
            'weblogs_create': 'dl.form > dd > input:eq(0)',
            'workspaces_create': 'dl.form > dd > input:eq(0)',
            'workspaces_settings_appearance': 'dl.form > dd > input:eq(0)'
        }
    },

    // Paths
    nlw_make_path: function(path) {
      return this.dev_mode
          ? path.replace(/(\d+\.\d+\.\d+\.\d+)/,'$1.'+(new Date).getTime())
          : path;
    },
    nlw_make_static_path: function(rest) {
        return this.nlw_make_path(this.static_path + rest);
    },
    nlw_make_js_path: function(file) {
        return this.nlw_make_path(['/js', this.version, file].join('/'));
    },
    nlw_make_plugin_path: function(rest) {
        return this.nlw_make_path(
            this.static_path.replace(/static/, 'nlw/plugin') + rest
        );
    },

    /**
     * Recreate the old Socialtext.var_name API that will be replaced with the
     * st API
     */
    setupLegacy: function() {
        $.extend(true, Socialtext, {
            version: this.version,
            new_page: this.new_page,
            accept_encoding: this.accept_encoding,
            loc_lang: this.loc_lang,
            dev_mode: this.dev_mode,

            // TODO
            start_in_edit_mode: false,
            double_click_to_edit: false, // if wikiwyg_double

            // Viewer
            real_user_id: this.viewer.user_id,
            userid: this.viewer.username,
            email_address: this.viewer.email_address,
            username: this.viewer.best_full_name,
            workspaces: this.viewer.workspaces,
            accounts: this.viewer.accounts,

            // Workspace
            wiki_id: this.workspace.name,
            wiki_title: this.workspace.title,
            comment_form_window_height:
                this.workspace.comment_form_window_height,

            // Page

            // Wikiwyg
            wikiwyg_variables: {
                dropshadow: {
                    defined: ''
                },
                is_new: this.page && this.page.is_new,
                is_incipient: this.page && this.page.is_incipient,
                plugins_enabled: this.plugins_enabled,
                plugins_enabled_for_current_workspace_account:
                    this.plugins_enabled_for_current_workspace_account,
                new_tags: this.page ? this.page.new_tags : [],
                miki_url: this.miki_url || '',
                ui_is_expanded: this.ui_is_expanded,
                user: {
                    is_guest: this.viewer.is_guest
                },
                page: this.page ? {
                    title: this.page.title || '',
                    display_title: this.page.display_title || '',
                    page_type: this.page.type || '',
                    revision_id: this.page.revision_id || '',
                    caller: this.page.caller || '',
                    new_title: this.page.new_title
                } : {},
                hub: {
                    current_workspace: this.workspace ? {
                        uri: this.workspace.uri,
                        allows_html_wafl: this.workspace.allows_html_wafl,
                        enable_spreadsheet: this.workspace.enable_spreadsheet,
                        enable_xhtml: this.workspace.enable_xhtml
                    } : {}
                },
                wiki: {
                    static_path: this.staic_path,
                    is_public: false
                }
            }
        });
    }
};

// Deprecated functions
nlw_make_s2_path = function (rest) {
    throw new Error('deprecated call to nlw_make_s2_path!');
}
nlw_make_s3_path = function (rest) {
    throw new Error('deprecated call to nlw_make_s3_path!');
}
nlw_make_skin_path = function (rest) {
    throw new Error('deprecated call to nlw_make_skin_path!');
}

// Legacy path functions
nlw_make_static_path = function(rest) { return st.nlw_make_static_path(rest) }
nlw_make_js_path = function(file) { return st.nlw_make_js_path(file) }
nlw_make_plugin_path = function(rest) { return st.nlw_make_plugin_path(rest) }

// Handy stuff
$('input.initial').live('click', function() {
  $(this).removeClass('initial').val('');
});

})(jQuery);
