(function($) {

$.fn.navList = function(opts) {
    var self = this;

    if (!opts.url || !opts.title || !opts.href)
        throw new Error("url, title and href are required");

    $.ajax({
        url: opts.url,
        type: 'get',
        dataType: 'json',
        success: function(data) {
            if (opts.sort) data = data.sort(opts.sort);
            $(self).each(function() {
                $(this).html(Jemplate.process('nav-list.tt2', {
                    loc: loc,
                    data: data,
                    opts: opts
                }));
            });
        }
    });
};

$.fn.peopleNavList = function () {
    $(this).navList({
        url: "/data/people/" + Socialtext.userid + "/watchlist",
        icon: function(p) { return '/data/people/' + p.id + '/small_photo' },
        href: function(p) { return '/st/profile/' + p.id },
        title: function(p) { return p.best_full_name },
        emptyMessage: loc("Currently, you are not following any people."),
        actions: [
            [ loc("People Directory..."), "/?action=people" ]
        ]
    });
};

})(jQuery);
