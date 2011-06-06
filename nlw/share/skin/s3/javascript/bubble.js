(function($){

Bubble = function (opts) {
    var self = this;
    $.extend(self, opts);
    $(this.node)
        .unbind('mouseover')
        .unbind('mouseout')
        .mouseover(function(){ self.mouseOver() })
        .mouseout(function(){ self.mouseOut() });
};

Bubble.prototype = {
    HOVER_TIMEOUT: 500,

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
        }, this.HOVER_TIMEOUT);
    },

    mouseOut: function() {
        this._state = 'hiding';
        var self = this;
        setTimeout(function(){
            if (self._state == 'hiding') {
                self.hide();
                self._state = 'hidden';
            }
        }, this.HOVER_TIMEOUT);
    },

    createPopup: function() {
        var self = this;
        this.contentNode = $('<div></div>')
            .addClass('inner');

        this.popup = $('<div></div>')
            .addClass('avatarPopup')
            .mouseover(function() { self.mouseOver() })
            .mouseout(function() { self.mouseOut() })
            .appendTo('body');

        // Add quote bubbles
        this.makeBubble('top', '/images/avatarPopupTop.png')
            .appendTo(this.popup);

        this.popup.append(this.contentNode)
        this.popup.append('<div class="clear"></div>');

        this.makeBubble('bottom', '/images/avatarPopupBottom.png')
            .appendTo(this.popup);
    },

    makeBubble: function(className, src) {
        var absoluteSrc = (''+document.location.href).replace(
            /^(\w+:\/+[^\/]+).*/, '$1' + nlw_make_s3_path(src)
        );
        var $div = $('<div></div>').addClass(className);
	if ($.browser.msie && $.browser.version < 7) {
            var args = "src='" + absoluteSrc + "', sizingMethod='crop'";
            $div.css(
                'filter',
                "progid:DXImageTransform.Microsoft"
                + ".AlphaImageLoader(" + args + ")"
            );
        }
        else {
            $div.css('background', 'transparent url('+absoluteSrc+') no-repeat');
        }
        return $div;
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
                .removeClass('underneath')
                .css('top', offset.top - this.popup.height() - 15);
        }
        else {
            this.popup
                .addClass('underneath')
                .css('top', offset.top + $node.height() + 5);
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
