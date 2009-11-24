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
                $(this).append(Jemplate.process('nav-list.tt2', {
                    loc: loc,
                    data: data,
                    opts: opts
                }));
            });
        }
    });

};

})(jQuery);
