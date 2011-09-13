gadgets.container.bindButtons = function() {
    $('#st-add-widget').click(function() {
        socialtext.dialog.show('opensocial-gallery', {
            view: gadgets.container.view,
            account_id: gadgets.container.viewer.primary_account_id || 0
        });
        return false;
    });

    $('#st-edit-layout').click(function() {
        gadgets.container.enterEditMode();
        return false;
    });

    $('#st-save-layout').click(function() {
        socialtext.dialog.show('save-layout');
        return false;
    });
    $('#st-cancel-layout').click(function() {
        self._in_edit_mode = false;
        gadgets.container.loadLayout(gadgets.container.base_url, function() {
            gadgets.container.leaveEditMode();
        });
        return false;
    });
    $('#st-revert-layout').click(function() {
        gadgets.container.loadDefaults();
        return false;
    });

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
