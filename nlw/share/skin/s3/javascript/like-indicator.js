(function($) {

LikeIndicator = function(opts) {
    $.extend(this, opts);
    this.others = this.isLikedByMe ? this.count - 1 : this.count;
    this.onlyFollows = true;
};

LikeIndicator.prototype = {
    loc: loc,
    limit: 5,

    render: function ($node) {
        var self = this;

        if ($node) {
            self.node = $node;
            self.node.html(Jemplate.process('like-indicator.tt2', self));
        }
        else {
            self.node.find('.like-indicator')
                .removeClass('me')
                .removeClass('others')
                .addClass(self.className())
                .attr('title', self.text())
                .html(self.text());
        }

        var $indicator = self.node.find('a.like-indicator');

        // If we already have a bubble, hide it quick before we recreate it
        self.startIndex = 0; // reset startIndex in case it's set

        if (self.bubble) {
            self.renderBubble();
        }
        else {
            var vars = {
                node: $indicator.get(0),
                onFirstShow: function() {
                    self.renderBubble();
                }
            };
            if ($indicator.parents('#controlsRight').size()) {
                vars.topOffset = 10; // XXX: weird
            }
            self.bubble = new Bubble(vars);
        }

        $indicator
            .unbind('click')
            .click(function() { self.toggleLike(); return false });
    },

    renderBubble: function() {
        var self = this;

        var url = self.url + '?' + $.param({
            startIndex: self.startIndex,
            limit: self.limit,
            only_follows: self.onlyFollows ? 1 : 0
        });

        $.getJSON(url, function(likers) {
            self.likers = likers;

            self.pages = [];
            for (var i=0; i * self.limit < likers.totalResults; i++) {
                self.pages.push({
                    num: i+1,
                    current: i * self.limit == self.startIndex
                });
            }
            var i = 0;

            self.bubble.html(Jemplate.process('like-bubble', self));

            // Actions:
            var $node = self.bubble.contentNode;
            $node.find('.like-indicator').click(function() {
                self.toggleLike();
                return false;
            });

            $node.find('.like-filter a').click(function() {
                if (!$(this).parent().hasClass(this.className)) {
                    self.onlyFollows = !self.onlyFollows;
                    self.renderBubble();
                }
                return false;
            });

            $.each(self.pages, function(count, page) {
                $node.find('.page' + page.num).click(function() {
                    self.startIndex = count * self.limit;
                    self.renderBubble();
                    return false;
                });
            });

            self.bubble.show();
        });
    },

    toggleLike: function() {
        var self = this;
        $.ajax({
            url: self.url + '/' + Socialtext.userid,
            type: self.isLikedByMe ? 'DELETE' : 'PUT',
            success: function() {
                if (self.isLikedByMe) {
                    self.isLikedByMe = false;
                    self.count--;
                }
                else {
                    self.isLikedByMe = true;
                    self.count++;
                }
                self.render();
            }
        });
    },

    className: function() {
        var classes = [];
        if (this.isLikedByMe) classes.push('me');
        if (this.others) classes.push('others');
        if (!this.mutable) classes.push('immutable');
        return classes.join(' ');
    },

    text: function(extended) {
        if (this.mutable) {
            return this.isLikedByMe ? loc('do.unlike') : loc('do.like')
        }
        else {
            return loc('like.like=count', this.count);
        }
    },

    likeText: function() {
        var others = this.isLikedByMe
            ? this.likers.totalResults - 1
            : this.likers.totalResults;

        if (others) {
            if (this.isLikedByMe) {
                if (this.onlyFollows) {
                    return loc('like.you-liked-this-page=followed', others);
                }
                else {
                    return loc('like.you-liked-this-page=others', others);
                }
            }
            else {
                if (this.onlyFollows) {
                    return loc('like.person-count=followed', others);
                }
                else {
                    return loc('like.person-count=others', others);
                }
            }
        }
        else {
            if (this.onlyFollows) {
                return loc('like.no-followed-users-like-this-page');
            }
            else {
                return loc('like.no-other-users-like-this-page');
            }
        }
    },

    likersPercentage: function() {
        return Math.floor(100 * this.count / this.total);
    }
};

$.fn.likeIndicator = function(opts) {
    if (!opts.url) throw new Error('opts required');
    $.each(this, function(_, node) {
        var indicator = new LikeIndicator(opts);
        indicator.render($(node));
    });
};

})(jQuery);
