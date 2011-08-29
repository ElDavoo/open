(function ($) {

var gallery = {
    hidden: {},

    gadgetVars: {
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
        },

        account_dashboard: {
            fixed: false,
            col: 2,
            row: 0
        }
    },

    show: function (args) {
        var self = this;
        $.extend(self, args);
        self.loadAccountGallery(function(gadgets) {
            self.dialog = socialtext.dialog.createDialog({
                title: loc('widget.insert'),
                width: 640,
                minWidth: 550,
                height: 400,
                html: socialtext.dialog.process('opensocial-gallery.tt2', {
                    gadgets: gadgets
                })
            });
            self.bindHandlers();
        });
    },

    bindHandlers: function() {
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
    },

    loadAccountGallery: function (callback) {
        var self = this;
        if (typeof(self.account_id) == 'undefined')
            throw new Error("account_id is required");
        if (typeof(self.type) == 'undefined')
            throw new Error("type is required");
        $.ajax({
            url: '/data/accounts/' + self.account_id + '/gadgets',
            dataType: 'json',
            success: function(gadgets) {
                var tables = [
                    { gadgets: [], title: loc('widget.socialtext') },
                    { gadgets: [], title: loc('widget.third-party') }
                ];
                $.each(gadgets, function(_, g){
                    var hidden = !g.src || g.removed || (
                        g.type && $.inArray(self.type, g.type) == -1
                    );
                    if (hidden) return;

                    tables[(g.socialtext == true) ? 0 : 1].gadgets.push(g);
                });

                callback(tables);
            }
        });
    }
};

socialtext.dialog.register('opensocial-gallery', function(args) {
    gallery.show(args);
});

})(jQuery);
