(function($) {

var LOAD_DELAY = 1500;

function fetchData(entries, index, callback) {
    if (index < entries.length) {
        var entry = entries[index];
        if (entry.url) {
            setTimeout(function() {
                var params = {};
                params[gadgets.io.RequestParameters.CONTENT_TYPE] =
                    gadgets.io.ContentType.JSON;
                var url = location.protocol + '//' + location.host
                        + entry.url;
                gadgets.io.makeRequest(url, function(response) {
                    if (entry.sort)
                        response.data = response.data.sort(entry.sort);
                    entry.data = response.data;

                    fetchData(entries, index + 1, callback);
                }, params);
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
    var $nodes = $(this);

    if (Number(st.viewer.is_guest)) return;

    fetchData(entries, 0, function() {
        $nodes.each(function(_, node) {
            var $node = $(node);
            $node.append(Jemplate.process('nav-list.tt2', {
                loc: loc,
                entries: entries
            }));

            $node.find('ul.navList li:last').addClass('last');

            if ($.browser.msie && $.browser.version <= 7) {
                $node.mouseover(function() {
                    $node.addClass('hover');
                })
                $node.mouseout(function() {
                    $node.removeClass('hover');
                });
            }
        });
    });
};

$.fn.peopleNavList = function(nodes) {
    $(this).each(function() {
        $(this).navList([
            { title: loc("nav.people-directory"), href: "/?action=people" },
            {
                url: "/data/people/" + Socialtext.userid + "/watchlist",
                icon: function(p) {
                    return '/data/people/' + p.id + '/small_photo'
                },
                href: function(p) { if (p) return '/st/profile/' + p.id },
                title: function(p) { return p.best_full_name },
                emptyMessage:
                    loc("nav.no-followers")
            }
        ]);
    });
};

})(jQuery);
