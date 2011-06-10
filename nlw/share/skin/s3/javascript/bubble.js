(function($){

Bubble = function (opts) {
    var self = this;
    $.extend(self, {}, self.defaults, opts);
    $(this.node)
        .unbind('mouseover')
        .unbind('mouseout')
        .mouseover(function(){ self.mouseOver() })
        .mouseout(function(){ self.mouseOut() });
};

Bubble.prototype = {
    defaults: {
        topOffset: 25,
        bottomOffset: 25,
        hoverTimeout: 500
    },

    mouseOver: function() {
        this._state = 'showing';
        var self = this;
        setTimeout(function(){
            if (self._state == 'showing') {
                if (!self.popup) {
                    self.createPopup();
                    self.onFirstShow();
                }
                else {
                    self.show();
                }
                self._state = 'shown';
            }
        }, this.hoverTimeout);
    },

    mouseOut: function() {
        this._state = 'hiding';
        var self = this;
        setTimeout(function(){
            if (self._state == 'hiding') {
                self.hide();
                self._state = 'hidden';
            }
        }, this.hoverTimeout);
    },

    createPopup: function() {
        var self = this;
        this.contentNode = $('<div></div>')
            .addClass('bubble');

        this.popup = $('<div></div>')
            .addClass('bubbleWrap')
            .mouseover(function() { self.mouseOver() })
            .mouseout(function() { self.mouseOut() })
            .appendTo('body');

        this.popup.append(this.contentNode)

        if (!$.browser.msie || ($.browser.msie && $.browser.version > 6)) {
            this.popup.append('<div class="before"></div>');
            this.popup.append('<div class="after"></div>');
        }

        this.popup.append('<div class="clear"></div>');
    },

    html: function(html) {
        this.contentNode.html(html);
    },

    append: function(html) {
        this.contentNode.append(html);
    },

    show: function() {
        // top was calculated based on $node's top, but if there was an
        // avatar image, we want to position off of the avatar's top
        var $img = $(this.node).find('img');
        var $node = $img.size() ? $img : $(this.node);
        var offset = $node.offset();

        // Check if the avatar is more than half of the way down the page
        var winOffset = $.browser.msie ? document.documentElement.scrollTop 
                                       : window.pageYOffset;
        if ((offset.top - winOffset) > ($(window).height() / 2)) {
            this.popup
                .removeClass('top')
                .css(
                    'top', offset.top - this.popup.height() - this.bottomOffset
                );
        }
        else {
            this.popup
                .addClass('top')
                .css('top', offset.top + $node.height() + this.topOffset);
        }

        this.popup.css('left', offset.left - 43 );

        if ($.browser.msie && this.popup.is(':hidden')) {
            // XXX
            var $vcard = $('.vcard', this.contentNode);
            this.popup.fadeIn('def', function() {
                // min-height: 62px
                if ($.browser.msie && $vcard.height() < 65) {
                    $vcard.height(65);
                }
            });
        }
        else {
            this.popup.fadeIn();
        }
    },

    hide: function() {
        if (this.popup) this.popup.fadeOut();
    }

};

})(jQuery);
