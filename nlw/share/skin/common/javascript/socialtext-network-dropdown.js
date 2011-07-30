// BEGIN Socialtext-Activities/jquery.dropdown.js
(function($){

Dropdown = function(args, node) {
    $.extend(this, $.extend(true, {}, args));
    this.node = node;
    if (!node) throw new Error("node is a required argument");

    var win = window;
    this.$ = window.$;
    try {
        // call window.parent.$ first to make sure we can access properties
        // of window.parent
        if (window.parent.$) {
            win = window.parent;
            this.$ = window.parent.$;
        }
    }
    catch(e) { }

    this.useParent = win != window;
    if (typeof(win.DD_COUNT) == 'undefined') win.DD_COUNT = 0;
    this.id = 'st-dropdown-' + win.DD_COUNT++;
}

Dropdown.prototype = {
    options: [],
    showCount: 0,
    mobile: /(iPad|iPod|iPhone|Android)/.test(navigator.userAgent),

    isSelected: function(option) {
        return option.value == this.selected || option.id == this.selected;
    },

    render: function() {
        var self = this;

        if (this.fixed) {
            this.valueNode = $('<span class="value"></span>');
            $(this.node).append(this.valueNode)
            $.each(this.options, function(i, option) {
                if (self.isSelected(option)) {
                    self._selectOption(option);
                }
            });
            return;
        }

        this.valueNode = $('<a href="#" class="value"></a>')
            .click(function(){ return false; });
        
        if (this.mobile) {
            this.valueNode = $('<span class="value fakeLink"></span>');
        }

        // Strip out hidden options
        this.options = $.grep(this.options, function(o) { return !o.hidden });

        this.$('body').append(Jemplate.process('dropdown.tt2', this));
        if (this.useParent) {
            $(window).unload(function() {
                self.listNode.remove();
            });
        }

        this.listNode = this.$('#' + this.id + '-list');
        if (!this.listNode.size())
            throw new Error("Can't find ul node");
        if (this.width) this.listNode.css('width', this.width);

        var $arrow = $('<span class="arrow">&#9660;</span>');

        $(this.node).append(this.valueNode).append($arrow);

        if (!self.mobile) {
            $(self.node).mouseover(function() { self.show() });
            $(self.node).mouseout(function() { self.hide() });
            self.listNode.mouseover(function() { self.show() });
            self.listNode.mouseout(function() { self.hide() });
        }

        if ($.browser.msie) {
            $('.options li').mouseover(function() {
                var li = this;
                setTimeout(function() {
                    $(li).addClass('hover');
                }, 0);
            });
            $('.options li').mouseout(function() {
                var li = this;
                setTimeout(function() {
                    $(li).removeClass('hover');
                }, 0);
            });
        }

        var $mobileSelect;
        $.each(this.options, function(i, option) {
            if (self.mobile) {
                if (!$mobileSelect) {
                    $mobileSelect = $('<select></select>')
                        .change(function() { self.selectValue($(this).val()) })
                        .appendTo(self.node);
                }
                $('<option></option>')
                    .attr('value', option.value)
                    .text(option.title)
                    .click(function() { self.selectValue(option.value) })
                    .appendTo($mobileSelect);
            }

            option.node = self.listNode.find('li a').get(i);
            self.$(option.node).click(function() {
                self.selectOption(option);
                return false;
            });
            if (self.isSelected(option)) {
                self._selectOption(option);
            }
        });
    },

    show: function() {
        var offset = this.useParent
            ? this.$('iframe[name='+window.name+']').offset()
            : {top: 0, left: 0};

        offset.left += this.$(this.node).offset().left;

        offset.top  += this.$(this.node).offset().top
                     + this.$(this.node).height()
                     - 1; // Offset to fix {bz: 3654}

        if (this.useParent) {
            // Fix {bz: 4711} when we are in an iframe, but don't trigger {bz: 4782} if we're not 
            offset.top -= (window.top.scrollY || 0);
            offset.left -= (window.top.scrollX || 0);
        }

        this.listNode.css({ 'left': offset.left, 'top': offset.top });

        this.showCount++; // cancel any pending hides
        this.listNode.show();
    },

    hide: function() {
        var self = this;
        // Only hide the listNode if we haven't called show() within 50ms of
        // creating this timeout:
        var cnt = self.showCount;
        setTimeout(function() {
            if (cnt == self.showCount) self.listNode.hide();
        }, 50);
    },

    _selectOption: function(option, callback) {
        if (!this.fixed) {
            if (this.$(option.node).parents('li.disabled.dropdownItem').size())
                return;
            this.listNode.find('li.selected').removeClass('selected');
            this.$(option.node).parents('li.dropdownItem').addClass('selected');

            // Hide the context menu
            this.listNode.hide();
        }

        // Store the selected option
        this._selectedOption = option;

        if (this.valueNode.text() != option.title) {
            // Display the new value and fire onChange if
            // the new value is different
            this.valueNode.text(option.title);

            // mobile
            if (this.mobile) {
                $(this.node).find('select')
                    .width(this.valueNode.width() + 10)
                    .val(option.value);
            }

            if ($.isFunction(callback)) {
                callback();
            }
        }
    },

    selectOption: function(option) {
        var self = this;
        this._selectOption(option, function() {
            if ($.isFunction(self.onChange)) {
                self.onChange(option);
            }
        });
    },

    selectedOption: function() {
        return this._selectedOption;
    },

    selectValue: function(value) {
        var self = this;
        $.each(this.options, function(i, option) {
            if (option.value == value) {
                self.selectOption(option);
            }
        });
    },

    selectId: function(id) {
        var self = this;
        $.each(this.options, function(i, option) {
            if (option.id == id) {
                self.selectOption(option);
            }
        });
    },

    enableAllOptions: function() {
        if (this.listNode)
            this.listNode.find('li.disabled').removeClass('disabled').show();
    },

    disableOption: function(value) {
        var self = this;
        var selected = self.selectedOption();

        // Step back to the first not disabled option
        if (selected) {
            if (selected.value == value) {
                var defaults = $.grep(self.options, function(item) {
                    return item['default']
                });
                if (!defaults.length) throw new Error("No default option!")
                self.selectOption(defaults[0]);
            }
        }

        $.each(self.options, function(i, option) {
            if (option.value == value) {
                $(option.node).parents('li.dropdownItem').addClass('disabled');
                if (self.hideDisabled)
                    $(option.node).parents('li.dropdownItem').hide();
            }
        });
    }
};

$.fn.extend({
    dropdown: function(args) {
        this.each(function() {
            if ($(this).hasClass('dropdown')) return;
            $(this).addClass('dropdown');
            this.dropdown = new Dropdown(args, this);
            this.dropdown.render();
        });
    },

    dropdownClick: function(linkNode) {
        this.each(function() {
            this.dropdown.click(linkNode);
        });
    },

    dropdownSelectValue: function(value) {
        $.each(this, function() {
            this.dropdown.selectValue(value);
        });
    },

    dropdownSelectId: function(value) {
        $.each(this, function() {
            this.dropdown.selectId(value);
        });
    },

    dropdownSelectedOption: function() {
        if (!this.size()) return;
        return this.get(0).dropdown.selectedOption();
    },

    dropdownValue: function() {
        if (!this.size()) return;
        var opt = this.get(0).dropdown.selectedOption();
        if (opt) return opt.value;
    },

    dropdownId: function() {
        if (!this.size()) return;
        var opt = this.get(0).dropdown.selectedOption();
        if (opt) return opt.id;
    },

    dropdownLabel: function() {
        if (!this.size()) return;
        var opt = this.get(0).dropdown.selectedOption();
        if (opt) return opt.title;
    },

    dropdownDisable: function(value) {
        $.each(this, function() {
            this.dropdown.disableOption(value);
        });
    },

    dropdownEnable: function() {
        $.each(this, function() {
            this.dropdown.enableAllOptions();
        });
    }
});
})(jQuery);
;
// BEGIN Socialtext-Activities/base.js
(function($) {

if (typeof(Activities) == 'undefined') Activities = {};

Activities.Base = function() {}

Activities.Base.prototype = {
    toString: function() { return 'Activities.Base' },

    extend: function(values) {
        var defaults = $.isFunction(this._defaults)
            ? this._defaults()
            : this._defaults;
        $.extend(true, this, defaults, values);
    },

    requires: function(requires) {
        var self = this;
        requires = requires.concat([
            'prefix', 'node'
        ]);
        $.each(requires, function(i, require) {
            if (typeof self[require] == 'undefined') {
                var err = self + ' requires ' + require;
                self.showError(err);
                throw new Error(err);
            }
        });
    },

    findId: function(id) {
        var win = arguments.length > 1 ? arguments[1] : window
        return $('#' + this.prefix + id);
    },

    hasTemplate: function(tmpl) {
        return Jemplate.templateMap[tmpl] ? true : false;
    },

    processTemplate: function(template, vars) {
        var self = this;
        var template_vars = {
            'this': self,
            'loc': loc,
            'id': function(rest) { return self.prefix + rest }
        };
        if (vars) $.extend(template_vars, vars);
        return Jemplate.process(template, template_vars);
    },

    makeRequest: function(uri, callback, force, vars) {
        var self = this;
        var params = {};
        params[gadgets.io.RequestParameters.CONTENT_TYPE] = 
            gadgets.io.ContentType.JSON;
        params[gadgets.io.RequestParameters.REFRESH_INTERVAL]
            = force ? 0 : 30;
        if (vars) $.extend(params, vars);
        gadgets.io.makeRequest(uri, function(data) {
            if (data.rc == 503) {
                // do it again in a second
                setTimeout(function() {
                    self.makeRequest(uri, callback, force);
                }, 1000);
            }
            else {
                callback(data);
            }
        }, params);
    },

    makePutRequest: function(uri, callback) {
        var params = {};
        params[gadgets.io.RequestParameters.METHOD]
            = gadgets.io.MethodType.PUT;
        this.makeRequest(uri, callback, true, params);
    },

    makeDeleteRequest: function(uri, callback) {
        var params = {};
        params[gadgets.io.RequestParameters.METHOD]
            = gadgets.io.MethodType.DELETE;
        this.makeRequest(uri, callback, true, params);
    },

    adjustHeight: function() {
        if (gadgets.window && gadgets.window.adjustHeight)
            gadgets.window.adjustHeight();
    },

    showMessageNotice: function (opts) {
        var $msg = this.addMessage({
            className: opts.className,
            onCancel: opts.onCancel,
            html: this.processTemplate(
                'activities/message_notice.tt2', opts
            )
        });
        if (opts.links) {
            $.each(opts.links, function(selector, onclick) {
                $msg.find(selector).click(onclick);
            });
        }
        this.adjustHeight();
        return $msg;
    },

    addMessage: function(opts) {
        // Don't show duplicate message types
        this.clearMessages(opts.className);

        var $msg = $('<div class="message"></div>')
            .addClass(opts.className)
            .html(opts.html)
            .prependTo(this.findId('messages'));

        // if there's an onCancel handler, add a [x] button
        if (opts.onCancel) {
            $msg.append(
                '[',
                $('<a href="#" class="cancel">x</a>')
                    .click(opts.onCancel),
                ']'
            );
        }

        this.adjustHeight();

        return $msg;
    },

    clearMessages: function() {
        var self = this;
        $.each(arguments, function(i, className) {
            self.findId('messages .' + className).remove();
        });
        this.adjustHeight();
    },

    showError: function(err) {
        if (err instanceof Error) err = err.message;
        if (this.findId('messages').size()) {
            this.addMessage({ className: 'error', html: err });
        }
        else {
            $(".error", this.node).remove();
            $(this.node).prepend("<span class='error'>"+err+"</span>");
        }
    },

    clearErrors: function() {
        if (!this.findId('messages').size()) {
            $(".error", this.node).remove();
        }
    },

    scrollTo: function($element) {
        $('html,body').animate({ scrollTop: $element.offset().top});
    },

    round: function(i) {
        return Math.round(i);
    },

    minutes_ago: function(at) {
        if (!at) return;
        var now = new Date();
        var then = new Date();
        then.setISO8601(at);
        return Math.round(
            (now.getTime() - then.getTime()) / 60000
        );
    }
};

})(jQuery);
;
// BEGIN Socialtext-Activities/appdata.js
(function($) {

if (typeof(Activities) == 'undefined') Activities = {};

Activities.AppData = function(opts) {
    this.extend(opts);
    this.requires([
        'instance_id', 'owner', 'viewer', 'owner_id'
    ]);
}

Activities.AppData.prototype = new Activities.Base()

$.extend(Activities.AppData.prototype, {
    toString: function() { return 'Activities.AppData' },

    _defaults: {
        fields: [ 'sort', 'network', 'action', 'feed', 'signal_network' ]
    }, 

    load: function(callback) {
        var self = this;

        var opensocial = rescopedOpensocialObject(self.instance_id);

        var getReq = opensocial.newDataRequest();
        var viewer = opensocial.newIdSpec({
            "userId" : opensocial.IdSpec.PersonId.VIEWER
        });
        getReq.add(
            getReq.newFetchPersonAppDataRequest(viewer, self.fields), "get_data"
        );

        var user = self.owner || self.viewer;

        getReq.add(
            new RestfulRequestItem(
                '/data/users/' + user + '?minimal=1', 'GET', null
            ), 'get_user'
        );

        getReq.add(
            new RestfulRequestItem(
                '/data/people/' + user + "/watchlist", 'GET', null
            ), 'get_watchlist'
        );

        getReq.send(function(dataResponse) {
            var appDataResult = dataResponse.get('get_data');
            if (appDataResult.hadError()) {
                self.showError(
                    "There was a problem getting user preferences"
                );
                return;
            }
            self.appData = appDataResult.getData();

            var userDataResult = dataResponse.get('get_user');
            if (userDataResult.hadError()) {
                self.showError(
                    "There was a problem getting user data"
                );
                return;
            }
            self.user_data = userDataResult.getData();

            var watchlistResult = dataResponse.get('get_watchlist');
            if (userDataResult.hadError()) {
                self.showError(
                    "There was a problem getting watchlist"
                );
                return;
            }
            var watchlistResultData = watchlistResult.getData();
            if (watchlistResultData) {
                self.watchlist = $.map(watchlistResult.getData(), function(u) {
                    return u.id;
                });
            }
            else {
                self.watchlist = [];
            }
            callback();
        });
    },

    save: function(key, val) {
        var self = this;
        self.appData[key] = val;

        // if instance_id == 0, we're somewhere like the signal-this popup
        if (!Number(self.instance_id)) return;

        var opensocial = rescopedOpensocialObject(self.instance_id);

        var setReq = opensocial.newDataRequest();
        setReq.add(
            setReq.newUpdatePersonAppDataRequest(
                opensocial.IdSpec.PersonId.VIEWER, key, val 
            ), 'set_data'
        );
        setReq.send(function(dataResponse) {
            if (dataResponse.hadError())  {
                self.showError(
                    "There was a problem setting user preferences"
                );
                return;
            }
            var dataResult = dataResponse.get('set_data');
            if (dataResult.hadError()) {
                self.showError(
                    "There was a problem setting user preferences"
                );
                return;
            }
        });
    },

    isBusinessAdmin: function() {
        return Number(this.user_data.is_business_admin);
    },

    accounts: function() {
        return this.user_data.accounts;
    },

    groups: function() {
        return this.user_data.groups;
    },

    getDefaultFilter: function(type) {
        var list = this.getList(type);
        var matches = $.grep(list, function(item) {
            return item['default'];
        });
        if (matches.length) return matches[0];
    },

    getList: function(key) {
        if (key == 'network') {
            return this.networks();
        }
        if (key == 'signal_network') {
            return this.signalNetworks();
        }
        else if (key == 'action') {
            return this.actions();
        }
        else if (key == 'feed') {
            return this.feeds();
        }
    },

    getById: function(type, id) {
        var list = this.getList(type);
        var matches = $.grep(list, function(item) {
            return item.id == id;
        });
        if (matches.length) return matches[0];
    },

    getByValue: function(type, value) {
        var list = this.getList(type);
        var matches = $.grep(list, function(item) {
            return item.value == value;
        });
        if (matches.length) return matches[0];
    },

    isShowingSignals: function () {
        return this.get('action').signals;
    },

    get: function(type) {
        var list = this.getList(type);

        // Check the appdata value
        var value = this['fixed_' + type] || this.appData[type];

        if (!list) return value;

        if (value) {
            // Value was either present in a cookie or pref, so return it
            var filter = this.getByValue(type, value)
                      || this.getById(type, value);
            if (filter) return filter;
        }

        // No value is set, so just use the first, default first
        list = list.slice();
        list.sort(function(a,b) {
            return a['default'] ? -1 : b['default'] ? 1 : 0;
        })
        return list[0];
    },

    getValue: function(type) {
        var filter =  this.get(type);
        if (!filter) throw new Error("Can't find filter value for " + type);
        return filter.value;
    },

    set: function(type, value) {
        if (!this.getById(type,value)) {
            throw new Error(
                "Invalid filter type or value: " + type + ':' + value
            );
        }
        this.save(type, value);
    },

    networks: function() {
        var self = this;
        if (self._networks) return self._networks;

        function name_sort(a,b) {
            var a_name = a.name || a.account_name;
            var b_name = b.name || b.account_name;
            return a_name.toUpperCase().localeCompare(b_name.toUpperCase());
        };

        var prim_acc_id = self.user_data.primary_account_id
        var sorted_accounts = self.user_data.accounts.sort(name_sort);
        var sorted_groups = self.user_data.groups.sort(name_sort);

        var networks = [];

        // Check for a fixed value
        $.each(sorted_accounts, function(i, acc) {
            var primary = acc.account_id == prim_acc_id ? true : false;
            var userlabel = (acc.user_count == 1) ? ' user)': ' users)';
            var title = acc.account_name + ' ('
                    + (primary ? loc('signals.primary-account=users', acc.user_count)
                               : loc('signals.network-count=users', acc.user_count))
                    + ')';

            $.extend(acc, {
                'default': primary,
                value: 'account-' + acc.account_id,
                id: 'account-' + acc.account_id,
                title: title,
                signals_size_limit:
                    acc.plugin_preferences.signals.signals_size_limit
            });

            if (self.isCurrentNetwork(acc.value)) {
                networks.push(acc);
            }

            // Now find the groups in that account
            $.each(sorted_groups, function(i, grp) {
                if (grp.primary_account_id == acc.account_id) {
                    var title = grp.name + ' (' + loc('signals.network-count=users', grp.user_count) + ')';
                    $.extend(grp, {
                        value: 'group-' + grp.group_id,
                        id: 'group-' + grp.group_id,
                        optionTitle: '... ' + title,
                        title: title,
                        signals_size_limit: acc.signals_size_limit,
                        plugins_enabled: acc.plugins_enabled
                    });
                    if (self.isCurrentNetwork(grp.value)) {
                        networks.push(grp);
                    }
                }
            });
        });

        // Add an option for all networks if there's more than one network
        if (networks.length == 0 && self.fixed_network) {
            networks = [
                {
                    value: self.fixed_network,
                    id: self.fixed_network,
                    title: this.group_name,
                    group_id: Number(self.fixed_network.replace(/group-/,'')),
                    plugins_enabled: []
                }
            ];
        }
        else if (networks.length > 1) {
            var title = this.owner == this.viewer
                      ? loc('activities.all-my-groups')
                      : loc('activities.all-shared-groups');
            networks.unshift({
                value: 'all',
                id: 'network-all',
                title: title,
                plugins_enabled: ['signals'],

                // Get the shortest signals_size_limit to set as limit
                // for all networks
                signals_size_limit: $.map(sorted_accounts, function(a) {
                    return a.signals_size_limit;
                }).sort(function (a, b){ return a-b }).shift()
            });
        }

        return this._networks = networks;
    },

    isCurrentNetwork: function(net) {
        return !this.fixed_network
            || this.fixed_network == 'all'
            || this.fixed_network == net;
    },

    signalNetworks: function() {
        var self = this;
        if (self._signal_networks) return self._signal_networks;

        var networks = [];
        $.each(self.networks(), function(i, network) {
            if (($.inArray('signals', network.plugins_enabled) != -1) && 
                (network.value != 'all')) {
                networks.push(network);
            }
        });

        return self._signal_networks = networks;
    },

    actions: function() {
        var self = this;
        if (self._actions) return self._actions;

        var all_events = {
            error_title: loc('activities.events'),
            title: loc('activities.all-events'),
            value: "activity=all-combined;with_my_signals=1",
            signals: true,
            'default': true,
            id: "action-all-events"
        };

        // {bz: 3950} - Don't show person events on the group homepage
        if (self.fixed_network) {
            all_events.value += ";event_class!=person";
        }

        var actions = [
            all_events,
            {
                title: loc('activities.signals'),
                value:"action=signal,edit_save,comment;signals=1;with_my_signals=1",
                id: "action-signals",
                signals: true,
                skip: !self.pluginsEnabled('signals', 'people')
            },
            {
                title: loc('activities.contributions'),
                value: "event_class=page;contributions=1;with_my_signals=1",
                id: "action-contributions"
            },
            {
                title: loc('activities.edits'),
                value: "event_class=page;action=edit_save",
                id: "action-edits"
            },
            {
                title: loc('activities.comments'),
                value: "event_class=page;action=comment",
                id: "action-comments"
            },
            {
                title: loc('activities.page-tags'),
                value: "event_class=page;action=tag_add,tag_delete",
                id: "action-tags"
            },
            {
                title: loc('activities.people-events'),
                value: "event_class=person" ,
                id: "action-people-events",
                skip: !self.pluginsEnabled('people')
            }
        ];

        // Check for a fixed value
        if (self.fixed_action) {
            actions = $.grep(actions, function(action) {
                return action.value == self.fixed_action
                    || action.id == self.fixed_action;
            });
        }

        return this._actions = actions;
    },

    feeds: function() {
        var self = this;
        if (self._feeds) return self._feeds;
        var feeds = [
            {
                title: loc('activities.everyone'),
                value: '',
                id: "feed-everyone",
                signals: true,
                'default': true
            },
            {
                title: loc('activities.following'),
                value: "/followed/" + self.viewer,
                id: "feed-followed",
                signals: true,
                skip: self.pluginsEnabled('people')
            },
            {
                title: loc('activities.my-conversations'),
                value: "/conversations/" + self.viewer,
                id: "feed-conversations"
            },
            {
                hidden: true,
                title: (self.viewer == self.owner) ? loc('activities.me') : (self.owner_name || 'Unknown User'),
                value: '/activities/' + self.owner_id,
                signals: true,
                id: 'feed-user'
            }
        ];

        // Check for a fixed value
        if (self.fixed_feed) {
            feeds = $.grep(feeds, function(feed) {
                return feed.value == self.fixed_feed
                    || feed.id == self.fixed_feed;
            });
        }

        return this._feeds = feeds;
    },

    getSignalToNetwork: function () {
        if (this._signalToNetwork) {
            return this.getByValue('network', this._signalToNetwork);
        }
        else {
            return this.get('network');
        }
    },

    pluginsEnabled: function() {
        var self = this;
        // Build a list of enabled plugins
        if (typeof(self._pluginsEnabled) == 'undefined') {
            self._pluginsEnabled = {};
            $.each(self.networks(), function(i, network) {
                // don't consider the fake "-all" network (which always
                // forces a fixed set of plugins)
                if (network.id == 'network-all') return;
                $.each(network.plugins_enabled, function(i, plugin) {
                    self._pluginsEnabled[plugin] = true;
                });
            });
        }

        var enabled = true;
        $.each(arguments, function(i, plugin) {
            if (!self._pluginsEnabled[plugin]) enabled = false;
        });
        return enabled;
    },

    setupDropdowns: function() {
        var self = this;

        this.findId('action').dropdown({
            options: self.actions(),
            selected: this.getValue('action'),
            fixed: Boolean(this.fixed_action),
            hideDisabled: Boolean(this.fixed_feed),
            onChange: function(option) {
                if (self.getValue('action') != option.id) {
                    self.set('action', option.id);
                }
                self.checkDisabledOptions();
                if (self.onRefresh) self.onRefresh();
            }
        });

        this.findId('feed').dropdown({
            options: self.feeds(),
            selected: this.getValue('feed'),
            fixed: Boolean(this.fixed_feed),
            hideDisabled: Boolean(this.fixed_action),
            onChange: function(option) {
                if (self.getValue('feed') != option.id) {
                    self.set('feed', option.id);
                }
                self.checkDisabledOptions();
                if (self.onRefresh) self.onRefresh();
            }
        });

        var fixed_network = Boolean(
            self.fixed_network || self.networks().length <= 1
        );

        this.findId('network').dropdown({
            selected: this.getValue('network'),
            fixed: fixed_network,
            width: '150px',
            options: self.networks(),
            onChange: function(option) {
                self.selectNetwork(option.id);
                if (self.onRefresh) self.onRefresh();
            }
        });

        var signal_network = this.get('signal_network');
        if (signal_network) {
            this.findId('signal_network').dropdown({
                selected: signal_network.id,
                fixed: fixed_network,
                width: (self.workspace_id ? '170px' : '150px'),
                options: self.signalNetworks(),
                onChange: function(option) {
                    if (option.warn) {
                        self.findId('signal_network_warning').fadeIn('fast');
                    }
                    else {
                        self.findId('signal_network_warning').fadeOut('fast');
                    }
                    self.selectSignalToNetwork(option.id);
                }
            });
            this.selectSignalToNetwork(signal_network.value);
            self.setupSelectSignalToNetworkWarningSigns();
        }
                
        this.checkDisabledOptions();
    },

    setupSelectSignalToNetworkWarningSigns: function() {
        var self = this;

        if (!self.workspace_id) {
            return;
        }

        if (!self.findId('signal_network').size()) {
            return;
        }

        $.getJSON('/data/workspaces/' + self.workspace_id, function(data) {
            var warningText = loc('info.edit-summary-signal-visibility');
            var dropdown = self.findId('signal_network').get(0).dropdown;
            var $firstGroup;
            var seenWarning = false;
            $.each(dropdown.options, function(i, option){
                var val = option.value;
                var $node = $(option.node);

                if (/^account-/.test(val)) {
                    if ((data.is_all_users_workspace) && (val == 'account-' + data.account_id)) {
                        // No warning signs for All-user workspace on the primary account
                        return;
                    }

                    option.warn = seenWarning = true;
                    $node.attr('title', warningText);
                    return;
                }

                var id = parseInt(val.substr(6));
                if ($.grep(data.group_ids, function(g) { return (g == id) }).length == 0) {
                    option.warn = seenWarning = true;
                    $node.attr('title', warningText);
                    return;
                }

                if (!$firstGroup) {
                    $firstGroup = $('<li style="font-weight: bold" class="dropdownItem">Non-workspace Groups</li>').css({
                        fontSize: '11px',
                        lineHeight: '12px',
                        fontFamily: 'arial,helvetica,sans-serif',
                        background: 'url(/static/skin/common/images/warning-icon.png) right top no-repeat'
                    }).attr('title', warningText).prependTo(dropdown.listNode);

                    $('<li style="font-weight: bold" class="dropdownItem">Workspace Groups</li>').css({
                        fontSize: '11px',
                        lineHeight: '12px',
                        fontFamily: 'arial,helvetica,sans-serif'
                    }).prependTo(dropdown.listNode);

                    dropdown._selectOption(option);
                    self.selectSignalToNetwork(option.value);
                }

                option.warn = false;
                option.node = $node.parent('li').remove().insertBefore($firstGroup).find('a:first').get(0);

                $(option.node).click(function() {
                    dropdown.selectOption(option);
                    return false;
                });
            });

            if (!$firstGroup) {
                $('<li style="font-weight: bold" class="dropdownItem">Non-workspace Groups</li>').css({
                    fontSize: '11px',
                    lineHeight: '12px',
                    fontFamily: 'arial,helvetica,sans-serif',
                    background: 'url(/static/skin/common/images/warning-icon.png) right top no-repeat'
                }).attr('title', warningText).prependTo(dropdown.listNode);

                dropdown._selectOption(dropdown.selectedOption());
            }

            if ($firstGroup && !seenWarning) {
                $firstGroup.remove();
            }

            if (dropdown.selectedOption().warn) {
                self.findId('signal_network_warning').fadeIn('fast');
            }
            else {
                self.findId('signal_network_warning').fadeOut('fast');
            }

            $(dropdown.listNode).css('overflow-x', 'hidden');
            if ($('li', dropdown.listNode).size() > 7) {
                $(dropdown.listNode).height(160).css('overflow-y', 'scroll');
            }
        });
    },

    checkDisabledOptions: function() {
        var self = this;
        var action = this.findId('action').dropdownSelectedOption();
        var feed = this.findId('feed').dropdownSelectedOption();
        if (!feed || !action) return;
        var not_conversations = {
            'action-tags' : 1,
            'action-people-events' : 1
        };

        self.findId('feed').dropdownEnable();
        self.findId('action').dropdownEnable();
        self.findId('network').dropdownEnable();
        if (self.signalNetworks().length) {
            self.findId('signal_network').dropdownEnable();
        }

        if (not_conversations[action.id]) {
            $.each(this.feeds(), function(i, option) {
                if (option.id == 'feed-conversations') {
                    self.findId('feed').dropdownDisable(option.value);
                }
            });
        }
        if (feed.id == 'feed-conversations') {
            $.each(this.actions(), function(i, option) {
                if (not_conversations[option.id]) {
                    self.findId('action').dropdownDisable(option.value);
                }
            });
        }
    },

    selectNetwork: function(network_id) {
        if (this.getValue('network') != network_id) {
            this.set('network', network_id);
        }

        if (this.findId('signals').size() && network_id != 'network-all') {
            this.selectSignalToNetwork(network_id);
        }

        if (this.findId('network').dropdownId() != network_id) {
            this.findId('network').dropdownSelectId(network_id);
        }

        this.findId('groupscope').text(this.get('network').title);
    },

    selectSignalToNetwork: function (network_id) {
        if (this.getValue('signal_network') != network_id) {
            this.set('signal_network', network_id);
        }

        var network = this.getById('network', network_id);
        this._signalToNetwork = network_id;
        if (this.findId('signal_network').dropdownId() != network_id) {
            this.findId('signal_network').dropdownSelectId(network_id);
        }
        if ($.inArray('signals', network.plugins_enabled) == -1) {
            this.disableSignals();
        }
        else {
            if (this.findId('signal_network').dropdownId() != network_id) {
                this.findId('signal_network').dropdownSelectId(network_id);
            }
            this._signalToNetwork = network_id;
            this.onSelectSignalToNetwork(network);
        }
    }

});

})(jQuery);
;
// BEGIN Socialtext-Activities/network_dropdown.js
(function($) {

if (typeof(Activities) == 'undefined') Activities = {};

Activities.NetworkDropdown = function(opts) {
    this.extend(opts);
    this.requires([
        'user', 'account_id'
    ]);
}

Activities.NetworkDropdown.prototype = new Activities.Base()

$.extend(Activities.NetworkDropdown.prototype, {
    toString: function() { return 'Activities.NetworkDropdown' },

    _defaults: {
        node: $('body')
    }, 

    show: function(callback) {
        var self = this;
        $.getJSON("/data/users/" + self.user, function(data) {
            self.appdata = new Activities.AppData({
                workspace_id: self.workspace_id,
                prefix: self.prefix,
                instance_id: 1,
                user_data: data,
                node: true,
                owner: true,
                viewer: true,
                owner_id: true
            });

            var default_network = 'account-' + self.account_id;
            self.findId('st-edit-summary-signal-to').val(default_network);

            self.appdata.selectSignalToNetwork = function(network){
                self.findId('st-edit-summary-signal-to').val(network);
            };

            self.findId('signal_network').text('').dropdown({
                selected: default_network,
                fixed: null,
                width: self.width || '170px',
                options: self.appdata.signalNetworks(),
                onChange: function(option) {
                    if (option.warn) {
                        self.findId('signal_network_warning').fadeIn('fast');
                    }
                    else {
                        self.findId('signal_network_warning').fadeOut('fast');
                    }
                    self.appdata.selectSignalToNetwork(option.value);
                    self.findId('st-edit-summary-signal-checkbox')
                        .attr('checked', true);
                }
            });

            self.findId('signal_network').children('a').css({ 
                width: ( 
                    self.width || ( 
                        ($.browser.msie && $.browser.version < 7) 
                            ? '85px' // IE6 
                            : '105px' 
                    ) 
                ), 
                verticalAlign: 'top', 
                height: '30px', 
                overflow: 'hidden', 
                display: 'inline-block', 
                whiteSpace: 'nowrap' 
            }); 

            if ($.browser.msie) {
                if (self.width) {
                    self.findId('signal_network').children('a').css({
                        height: '16px',
                        marginTop: '7px'
                    });
                }
                else {
                    self.findId('signal_network').children('a').css({
                        marginLeft: '-4px',
                        marginTop: '-9px'
                    });
                }
            }
            else if (self.width) {
                self.findId('signal_network').children('a').css({
                    marginTop: '2px'
                });
            }

            self.findId('signal_network').find('.dropdownOptions').css({
                'margin-top': '-15px',
                'margin-left': '11em'
            });
            self.findId('signal_network').find('.dropdownOptions li').css({
                'line-height': '16px'
            });

            self.appdata.setupSelectSignalToNetworkWarningSigns();
        });
    }
});

})(jQuery);
;
