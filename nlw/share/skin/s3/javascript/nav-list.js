(function($) {

var LOAD_DELAY = 1500;

function fetchData(entries, index, callback) {
    if (index < entries.length) {
        var entry = entries[index];
        if (entry.url) {
            setTimeout(function() {
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
            }, LOAD_DELAY);
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

            if ($.browser.msie && $.browser.version < 7) {
                $(this).parents('.submenu')
                    .mouseover(function() {
                        $(this).addClass('hover');
                    })
                    .mouseout(function() {
                        $(this).removeClass('hover');
                    });
            }

            $('.scrollingNav', this).each(function() {
                // Show a maximum of 8 entries (AKA cross-browser max-height)
                var li_height = $(this).hasClass('has_icons') ? 30 : 20;
                if ($(this).find('li').size() >= 8) {
                    $(this).height(li_height * 8);
                    $(this).css('overflow-y', 'scroll');
                }
            });

            $('li.scrollingNav li:last, li:last', this).addClass('last');
        });
    });
};

})(jQuery);
