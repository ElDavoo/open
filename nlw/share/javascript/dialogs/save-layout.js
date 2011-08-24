var ST = window.ST = window.ST || {};
(function($) {

ST.SaveLayout = function () {};
var proto = ST.SaveLayout.prototype = {
};

proto.show = function () {
    var self = this;

    var redirect = function () { $.hideLightbox(); document.location = '/'; };
    var $pushWidgets = jQuery('.push-widget:checked');
    var pushGadgetIds = [];
    var pushGadgetTitles = [];
    $.each($pushWidgets, function (i, checkbox) {
        pushGadgetIds.push(checkbox.id.match(/_(\d+)$/)[1]);
        pushGadgetTitles.push(checkbox.name);
    });
    var dialog = Socialtext.Dialog.Create({
        html: Jemplate.process('save-layout.tt2', {
            'gadget_titles': pushGadgetTitles,
            'loc': loc
        }),
        title: loc('dashboard.save-confirmation')
    });

    dialog.find('.save').click(function () {
        var force = dialog.find('#force-update').is(':checked');
        var push_widgets = !force && pushGadgetIds.length;

        gadgets.container.saveAdminLayout({
            push: push_widgets,
            purge: force,
            success: function() {
                dialog.close();
                gadgets.container.loadLayout('/st/dashboard', function() {
                    gadgets.container.leaveEditMode();

                    if (force) {
                        Socialtext.Dialog.ShowResult(
                            loc('dashboard.successfully-reset')
                        );
                    }
                    else {
                        Socialtext.Dialog.ShowResult(
                            loc('dashboard.successfully-saved')
                        );
                    }
                })
            }
        });

        // Error handling???
        // loc('error.dashboard-push-widget'),
        // loc('error.dashboard-reset'),
        return false;
    });
};
})(jQuery);

