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
        }),
        buttons: [
            {
                name: loc('do.save'),
                id: 'st-save-widget-template',
                callback: function() {
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
                }
            },
            {
                name: loc('do.cancel'),
                callback: function() {
                    dialog.close();
                }
            }
        ]
    });
});

})(jQuery);

