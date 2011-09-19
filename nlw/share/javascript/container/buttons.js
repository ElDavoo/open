gadgets.container.bindButtons = function() {

    // Most Containers - Gallery
    $('#st-add-widget').click(function() {
        socialtext.dialog.show('opensocial-gallery', {
            view: gadgets.container.view,
            account_id: gadgets.container.viewer.primary_account_id || 0
        });
        return false;
    });

    // Most Containers - Layouts
    $('#st-edit-layout').click(function() {
        gadgets.container.enterEditMode();
        return false;
    });
    $('#st-save-layout').click(function() {
        socialtext.dialog.show('save-layout');
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

    // Group Container - Edit Group
    if (gadgets.container.group) {
        $('#st-edit-group').attr(
            'href', '/st/edit_group/' + gadgets.container.group.id
        );
    }

    // Group Container - Leave Group
    $('#st-leave-group').click(function() {
        socialtext.dialog.show('groups-leave', {
            onConfirm: function() { leave('/st/dashboard') }
        });
        return false;
    });

    // People Container - Edit Profile
    $('#st-edit-profile').attr('href', '/st/edit_profile');

    // People Container - Watch / UnWatch
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
