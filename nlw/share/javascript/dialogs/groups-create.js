(function ($) {

socialtext.dialog.register('groups-create', function(opts) {
    var dialog = socialtext.dialog.createDialog({
        html: socialtext.dialog.process('groups-create.tt2', opts),
        title: opts.title
    });

    var group_data = {};
    var widgets = ['widget_0', 'widget_1', 'widget_2'];

    dialog.disable();
    dialog.find('.error').text('');

    function done(res) {
        if (res.errors && res.errors.length) {
            dialog.enable();
            dialog.find('.error').text(res.errors[0]);
        }
        else {
            window.location = '/st/group/' + res.group_id;
        }
    }

    function nextStep() {
        var next = widgets.shift();
        if (next) {
            gadgets.rpc.call(next, 'get_data', function(widget_data) {
                if (widget_data) {
                    $.extend(true, group_data, widget_data); //deep extend
                    setTimeout(nextStep, 500);
                }
                else {
                    dialog.enable();
                }
            });
        }
        else {
            if (group_data.group_id) {
                var group = new Socialtext.Group(group_data);
                group.save(done);
            }
            else {
                // Create the new group
                Socialtext.Group.Create(group_data, done);
            }
        }
    }

    nextStep();

    return false;
});

})(jQuery);
