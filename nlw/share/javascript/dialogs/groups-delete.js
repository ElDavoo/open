(function ($) {

socialtext.dialog.register('groups-delete', function(opts) {
    var dialog = socialtext.dialog.createDialog({
        html: socialtext.dialog.process('groups-delete.tt2', opts),
        title: loc('groups.delete=name', opts.group_name),
        buttons: [
            {
                name: loc('do.delete'),
                callback: function() {
                    dialog.disable();
                    var group = new Socialtext.Group({
                        group_id: opts.group_id
                    });
                    group.remove(function(res) {
                        if (res.errors && res.errors.length) {
                            dialog.find('.error').html(res.errors[0]);
                            dialog.enable();
                        }
                        else {
                            dialog.close();
                            location = '/st/dashboard';
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

