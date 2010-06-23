(function($) {

function fetchData(entries, index, callback) {
    if (index < entries.length) {
        var entry = entries[index];
        if (entry.url) {
            $.ajax({
                url: entry.url,
                type: 'get',
                dataType: 'json',
                success: function(data) {
                    if (entry.sort) data = data.sort(entry.sort);
                    entry.data = data;

                    fetchData(entries, index + 1, callback);
                }
            });
        }
        else {
            // skip loading data, move on to the next entry
            fetchData(entries, index + 1, callback);
        }
    }
    else {
        callback(); // Done loading all data
    }
}

$.fn.navList = function(entries) {
    var self = this;

    fetchData(entries, 0, function() {
        $(self).each(function() {
            $(this).html(Jemplate.process('nav-list.tt2', {
                loc: loc,
                entries: entries
            }));

            $('.scrollingNav', this).each(function() {
                // Show a maximum of 8 entries (AKA cross-browser max-height)
                var li_height = $(this).hasClass('has_icons') ? 30 : 20;
                if ($(this).find('li').size() >= 8) {
                    $(this).height(li_height * 8);
                }
            });

            $('li.scrollingNav li:last, li:last', this).addClass('last');
        });
    });
};

})(jQuery);
