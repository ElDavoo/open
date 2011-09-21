(function($) {

var button_handler = {
    // gallery
    'st-add-widget': function() {
        socialtext.dialog.show('opensocial-gallery', {
            view: gadgets.container.view,
            account_id: gadgets.container.viewer.primary_account_id || 0
        });
    },

    // layouts
    'st-edit-layout':  function() {
        gadgets.container.enterEditMode();
    },
    'st-save-layout': function() {
        if (gadgets.container.type == 'account_dashboard') {
            // Show a confirmation dialog
            socialtext.dialog.show('save-layout');
        }
        else {
            // Just save
            gadgets.container.saveAdminLayout({
                success: function() {
                    gadgets.container.leaveEditMode();
                }
            });
        }
    },
    'st-cancel-layout': function() {
        gadgets.container.loadLayout(
            gadgets.container.base_url,
            function() { gadgets.container.leaveEditMode() }
        );
    },
    'st-revert-layout': function() {
        gadgets.container.loadDefaults();
    },

    /**
     * Group Container
     */

    // edit
    'st-edit-group': function() {
        location = '/st/edit_group/' + gadgets.container.group.id;
    },

    // leave
    'st-leave-group': function() {
        socialtext.dialog.show('groups-leave', {
            onConfirm: function() { leave('/st/dashboard') }
        });
    },

    // join
    'st-join-group': function() {
        var group = new Socialtext.Group({
            group_id: gadgets.container.group.id,
            permission_set: gadgets.container.group.permission_set
        });

        var group_data = {
            users: [ {user_id: st.viewer.user_id} ]
        };
        group.addMembers(group_data, function(data) {
            if (data.errors) {
                socialtext.dialog.showError(data.errors[0]);
            }
            else {
                window.location = '/st/group/'
                    + gadgets.container.group.id + '?_=self-joined';
            }
        });
    },

    /**
     * Edit Group Container
     */
    
    // delete
    'st-delete-group': function() {
        socialtext.dialog.show('groups-delete', {
            group_id: gadgets.container.group.id,
            group_name: gadgets.container.group.name
        });
    },

    // Create/Save
    'create-group': function() {
        socialtext.dialog.show('groups-save', { });
    },

    // Cancel
    'st-cancel-create-group': function() {
        window.location = gadgets.container.group
            ? '/st/group/' + gadgets.container.group.id
            : '/st/dashboard';
    },

    /**
     * Profile Container
     */

    // edit
    'st-edit-profile': function() {
        window.location = '/st/edit_profile';
    }
}

    // follow / unfollow
/*
    var $indicator = $('#st-watchperson-indicator');
    if ($indicator.size()) {
        function updateNetworksWidget() {
            try {
                gadgets.rpc.call('..', 'pubsub', null, 'publish', 'update');
            } catch (e) {}
        }

        var person = new Person({
            id: gadgets.container.owner.user_id,
            best_full_name: gadgets.container.owner.name,
            self: false,
            onFollow: updateNetworksWidget,
            onStopFollowing: updateNetworksWidget
        });
        person.loadWatchlist(function() {
            person.createFollowLink($indicator);
        });
    }
*/
 
Socialtext.prototype.buttons = {
    show: function(buttons) {
        $.each(buttons, function(_, b) {
            var button_id = b[0]
            var button_text = b[1]
            var button_class = b[2]

            var handler = button_handler[button_id];
            if (!handler) throw new Error('No handler for ' + button_id);
            $('<button/>')
                .addClass(button_class)
                .button({
                    label: button_text,
                })
                .click(handler)
                .appendTo('#globalNav .buttons');
        });
    }
}

})(jQuery);
