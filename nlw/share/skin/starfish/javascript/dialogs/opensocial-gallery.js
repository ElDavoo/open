var ST = window.ST = window.ST || {};
(function ($) {

ST.OpenSocialGallery = function (options) { $.extend(this, options) };

var proto = ST.OpenSocialGallery.prototype = {
};

proto.hidden = {};

proto.gadgetVars = {
    profile: {
        fixed: true,
        'class': 'tan',
        col: 2,
        row: 0
    },

    dashboard: {
        fixed: false,
        col: 2,
        row: 0
    }
};

proto.showLightbox = function () {
    var self = this;
    self.loadAccountGallery(function(widgets) {
        self.dialog = Socialtext.Dialog.Create({
            title: loc('widget.insert'),
            width: 640,
            minWidth: 550,
            height: 400,
            html: Socialtext.Dialog.Process('opensocial-gallery.tt2', {
                widgets: widgets
            })
        });
        self.bindHandlers();
    });
}

proto.bindHandlers = function() {
    var self = this;
    self.dialog.find("a.add-now").click(function(){
        var $button = $(this);
        var src = $button.siblings('input[name=src]').val();
        var gadget_id = $button.siblings('input[name=gadget_id]').val();

        if (!self.gadgetVars[self.type])
            throw new Error('No vars for ' + self.type);
        var vars = $.extend({
            gadget_id: gadget_id
        }, self.gadgetVars[self.type]);

        gadgets.container.add_gadget(vars);
        self.dialog.close();
        return false;
    });
};

proto.loadAccountGallery = function (callback) {
    var self = this;
    if (typeof(self.account_id) == 'undefined')
        throw new Error("account_id is required");
    if (typeof(self.type) == 'undefined')
        throw new Error("type is required");
    $.ajax({
        url: '/data/accounts/' + self.account_id + '/gallery',
        dataType: 'json',
        success: function(gallery) {
            var tables = [
                { widgets: [], title: loc('widget.socialtext') },
                { widgets: [], title: loc('widget.third-party') }
            ];
            var widgets = gallery.widgets;
            $.each(widgets, function(){
                var hidden = !this.src || this.removed || (
                    this.type && $.inArray(self.type, this.type) == -1
                );
                if (hidden) return;

                tables[(this.socialtext == true) ? 0 : 1].widgets.push(this);
            });

            callback(tables);
        }
    });
};

})(jQuery);
