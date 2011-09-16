(function($) {

socialtext.dialog.register('save-layout', function() {
    var $pushWidgets = jQuery('.push-widget:checked');
    var pushGadgetIds = [];
    var pushGadgetTitles = [];
    $.each($pushWidgets, function (i, checkbox) {
        pushGadgetIds.push(checkbox.id.match(/_(\d+)$/)[1]);
        pushGadgetTitles.push(checkbox.name);
    });
    var dialog = socialtext.dialog.createDialog({
        title: loc('dashboard.save-confirmation'),
        html: socialtext.dialog.process('save-layout.tt2', {
            gadget_titles: pushGadgetTitles,
            type: gadgets.container.type,
        })
    });

    dialog.find('.cancel').click(function() {
        dialog.close();
        return false;
    });

    dialog.find('.save').click(function () {
        var force = dialog.find('#force-update').is(':checked');
        var push_widgets = !force && pushGadgetIds.length;

        gadgets.container.saveAdminLayout({
            push: push_widgets,
            purge: force,
            success: function() {
                dialog.close();
                gadgets.container.leaveEditMode();
            }
        });

        // Error handling???
        // loc('error.dashboard-push-widget'),
        // loc('error.dashboard-reset'),
        return false;
    });
});

})(jQuery);

