(function($) {

LikeIndicator = function(opts) {
    $.extend(this, opts);
    this.others = this.isLikedByMe ? this.count - 1 : this.count;
};

LikeIndicator.prototype = {
    loc: loc,

    render: function ($node) {
        var self = this;

        $node.html(Jemplate.process('like-indicator.tt2', self));
        var $indicator = $node.find('a.like-indicator');

        // If we already have a bubble, hide it quick before we recreate it
        if (self.bubble) self.bubble.hide();

        self.bubble = new Bubble({
            node: $indicator.get(0),
            onFirstShow: function() {
                $.getJSON(self.url, function(likers) {
                    self.likers = likers;
                    self.bubble.html(Jemplate.process('like-bubble', self));
                    self.bubble.contentNode.find('.like-indicator')
                        .click(function() { return self.toggleLike($node) });
                    self.bubble.show();
                });
            }
        });

        $indicator.click(function() { return self.toggleLike($node) });
    },

    toggleLike: function($node) {
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
                self.render($node);
            }
        });
        return false;
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
