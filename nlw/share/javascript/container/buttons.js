gadgets.container.bindButtons = function() {
    /**
     * Most Containers
     */

    // gallery
    $('#st-add-widget').click(function() {
        socialtext.dialog.show('opensocial-gallery', {
            view: gadgets.container.view,
            account_id: gadgets.container.viewer.primary_account_id || 0
        });
        return false;
    });

    // layouts
    $('#st-edit-layout').click(function() {
        gadgets.container.enterEditMode();
        return false;
    });
    $('#st-save-layout').click(function() {
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
        return false;
    });
    $('#st-cancel-layout').click(function() {
        gadgets.container.loadLayout(gadgets.container.base_url, function() {
            gadgets.container.leaveEditMode();
        });
        return false;
    });
    $('#st-revert-layout').click(function() {
        gadgets.container.loadDefaults();
        return false;
    });

    /**
     * Group Container
     */

    // edit
    if (gadgets.container.group) {
        $('#st-edit-group').attr(
            'href', '/st/edit_group/' + gadgets.container.group.id
        );
    }

    // leave
    $('#st-leave-group').click(function() {
        socialtext.dialog.show('groups-leave', {
            onConfirm: function() { leave('/st/dashboard') }
        });
        return false;
    });

    // join
    $('#st-join-group').click(function() {
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
                return false;
            }
            window.location =
                '/st/group/' + gadgets.container.group.id + '?_=self-joined';
        });
        return false;
    });

    /**
     * Edit Group Container
     */
    
    // delete
    $('#st-delete-group').click(function() {
        socialtext.dialog.show('groups-delete', {
            group_id: gadgets.container.group.id,
            group_name: gadgets.container.group.name
        });
        return false;
    });

    // Create/Save
    $('#create-group').click(function() {
        socialtext.dialog.show('groups-save', { });
        return false;
    });

    // Cancel
    $('#st-cancel-create-group').attr('href',
        gadgets.container.group
            ? '/st/group/' + gadgets.container.group.id
            : '/st/dashboard'
    );

    /**
     * Profile Container
     */

    // edit
    $('#st-edit-profile').attr('href', '/st/edit_profile');

    // follow / unfollow
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
};
