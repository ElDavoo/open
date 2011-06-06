(function($) {

LikeIndicator = function(opts) {
    $.extend(this, opts);
    this.others = this.isLikedByMe ? this.count - 1 : this.count;
};

LikeIndicator.prototype = {
    loc: loc,

    render: function ($node) {
        var self = this;

        if ($node) self.node = $node;

        self.node.html(Jemplate.process('like-indicator.tt2', self));
        var $indicator = self.node.find('a.like-indicator');

        // If we already have a bubble, hide it quick before we recreate it
        if (self.bubble) self.bubble.hide();
        self.startIndex = 0; // reset startIndex in case it's set

        self.bubble = new Bubble({
            node: $indicator.get(0),
            onFirstShow: function() {
                self.renderBubble();
            }
        });

        $indicator.click(function() { return self.toggleLike(); return false });
    },

    renderBubble: function() {
        var self = this;

        var url = self.url + '?' + $.param({
            startIndex: self.startIndex,
            limit: 10
        });

        $.getJSON(url, function(likers) {
            self.likers = likers;
            self.bubble.html(Jemplate.process('like-bubble', self));

            // Actions:
            var $node = self.bubble.contentNode;
            $node.find('.like-indicator').click(function() {
                self.toggleLike();
                return false;
            });
            $node.find('.prev').click(function() {
                self.startIndex -= 10;
                self.renderBubble();
                return false;
            });
            $node.find('.next').click(function() {
                self.startIndex += 10;
                self.renderBubble();
                return false;
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
        return classes.join(' ');
    },

    text: function(extended) {
        if (extended)
            return this.isLikedByMe ? loc('Unlike this page') : loc('Like this page')
        return this.isLikedByMe ? loc('Unlike') : loc('Like')
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
