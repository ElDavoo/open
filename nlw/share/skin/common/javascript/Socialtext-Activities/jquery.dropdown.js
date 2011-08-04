(function($){

Dropdown = function(args, node) {
    $.extend(this, $.extend(true, {}, args));
    this.node = node;
    if (!node) throw new Error("node is a required argument");

    var win = window;
    this.$ = window.$;
    try {
        // call window.parent.$ first to make sure we can access properties
        // of window.parent
        if (window.parent.$) {
            win = window.parent;
            this.$ = window.parent.$;
        }
    }
    catch(e) { }

    this.useParent = win != window;
    if (typeof(win.DD_COUNT) == 'undefined') win.DD_COUNT = 0;
    this.id = 'st-dropdown-' + win.DD_COUNT++;
}

Dropdown.prototype = {
    options: [],
    showCount: 0,
    mobile: /(iPad|iPod|iPhone|Android)/.test(navigator.userAgent),

    isSelected: function(option) {
        return option.value == this.selected || option.id == this.selected;
    },

    render: function() {
        var self = this;

        if (this.fixed) {
            this.valueNode = $('<span class="value"></span>');
            $(this.node).append(this.valueNode)
            $.each(this.options, function(i, option) {
                if (self.isSelected(option)) {
                    self._selectOption(option);
                }
            });
            return;
        }

        this.valueNode = $('<a href="#" class="value"></a>')
            .click(function(){ return false; });
        
        if (this.mobile) {
            this.valueNode = $('<span class="value fakeLink"></span>');
        }

        // Strip out hidden options
        this.options = $.grep(this.options, function(o) { return !o.hidden });

        this.$('body').append(Jemplate.process('dropdown.tt2', this));
        if (this.useParent) {
            $(window).unload(function() {
                self.listNode.remove();
            });
        }

        this.listNode = this.$('#' + this.id + '-list');
        if (!this.listNode.size())
            throw new Error("Can't find ul node");
        if (this.width) this.listNode.css('width', this.width);

        var $arrow = $('<span class="arrow">&#9660;</span>');

        $(this.node).append(this.valueNode).append($arrow);

        if (!self.mobile) {
            $(self.node).mouseover(function() { self.show() });
            $(self.node).mouseout(function() { self.hide() });
            self.listNode.mouseover(function() { self.show() });
            self.listNode.mouseout(function() { self.hide() });
        }

        if ($.browser.msie) {
            $('.options li').mouseover(function() {
                var li = this;
                setTimeout(function() {
                    $(li).addClass('hover');
                }, 0);
            });
            $('.options li').mouseout(function() {
                var li = this;
                setTimeout(function() {
                    $(li).removeClass('hover');
                }, 0);
            });
        }

        var $mobileSelect;
        $.each(this.options, function(i, option) {
            if (self.mobile) {
                if (!$mobileSelect) {
                    $mobileSelect = $('<select></select>')
                        .change(function() { self.selectValue($(this).val()) })
                        .appendTo(self.node);
                }
                $('<option></option>')
                    .attr('value', option.value)
                    .text(option.title)
                    .click(function() { self.selectValue(option.value) })
                    .appendTo($mobileSelect);
            }

            option.node = self.listNode.find('li a').get(i);
            self.$(option.node).click(function() {
                self.selectOption(option);
                return false;
            });
            if (self.isSelected(option)) {
                self._selectOption(option);
            }
        });
    },

    show: function() {
        var offset = this.useParent
            ? this.$('iframe[name='+window.name+']').offset()
            : {top: 0, left: 0};

        offset.left += this.$(this.node).offset().left;

        offset.top  += this.$(this.node).offset().top
                     + this.$(this.node).height()
                     - 1; // Offset to fix {bz: 3654}

        if (this.useParent) {
            // Fix {bz: 4711} when we are in an iframe, but don't trigger {bz: 4782} if we're not 
            offset.top -= (window.top.scrollY || 0);
            offset.left -= (window.top.scrollX || 0);
        }

        this.listNode.css({ 'left': offset.left, 'top': offset.top });

        this.showCount++; // cancel any pending hides
        this.listNode.show();
    },

    hide: function() {
        var self = this;
        // Only hide the listNode if we haven't called show() within 50ms of
        // creating this timeout:
        var cnt = self.showCount;
        setTimeout(function() {
            if (cnt == self.showCount) self.listNode.hide();
        }, 50);
    },

    _selectOption: function(option, callback) {
        if (!this.fixed) {
            if (this.$(option.node).parents('li.disabled.dropdownItem').size())
                return;
            this.listNode.find('li.selected').removeClass('selected');
            this.$(option.node).parents('li.dropdownItem').addClass('selected');

            // Hide the context menu
            this.listNode.hide();
        }

        // Store the selected option
        this._selectedOption = option;

        if (this.valueNode.text() != option.title) {
            // Display the new value and fire onChange if
            // the new value is different
            this.valueNode.text(option.title);

            // mobile
            if (this.mobile) {
                $(this.node).find('select')
                    .width(this.valueNode.width() + 10)
                    .val(option.value);
            }

            if ($.isFunction(callback)) {
                callback();
            }
        }
    },

    selectOption: function(option) {
        var self = this;
        this._selectOption(option, function() {
            if ($.isFunction(self.onChange)) {
                self.onChange(option);
            }
        });
    },

    selectedOption: function() {
        return this._selectedOption;
    },

    selectValue: function(value) {
        var self = this;
        $.each(this.options, function(i, option) {
            if (option.value == value) {
                self.selectOption(option);
            }
        });
    },

    selectId: function(id) {
        var self = this;
        $.each(this.options, function(i, option) {
            if (option.id == id) {
                self.selectOption(option);
            }
        });
    },

    enableAllOptions: function() {
        if (this.listNode)
            this.listNode.find('li.disabled').removeClass('disabled').show();
    },

    disableOption: function(value) {
        var self = this;
        var selected = self.selectedOption();

        // Step back to the first not disabled option
        if (selected) {
            if (selected.value == value) {
                var defaults = $.grep(self.options, function(item) {
                    return item['default']
                });
                if (!defaults.length) throw new Error("No default option!")
                self.selectOption(defaults[0]);
            }
        }

        $.each(self.options, function(i, option) {
            if (option.value == value) {
                $(option.node).parents('li.dropdownItem').addClass('disabled');
                if (self.hideDisabled)
                    $(option.node).parents('li.dropdownItem').hide();
            }
        });
    }
};

$.fn.extend({
    dropdown: function(args) {
        this.each(function() {
            if ($(this).hasClass('dropdown')) return;
            $(this).addClass('dropdown');
            this.dropdown = new Dropdown(args, this);
            this.dropdown.render();
        });
    },

    dropdownClick: function(linkNode) {
        this.each(function() {
            this.dropdown.click(linkNode);
        });
    },

    dropdownSelectValue: function(value) {
        $.each(this, function() {
            this.dropdown.selectValue(value);
        });
    },

    dropdownSelectId: function(value) {
        $.each(this, function() {
            this.dropdown.selectId(value);
        });
    },

    dropdownSelectedOption: function() {
        if (!this.size()) return;
        return this.get(0).dropdown.selectedOption();
    },

    dropdownValue: function() {
        if (!this.size()) return;
        var opt = this.get(0).dropdown.selectedOption();
        if (opt) return opt.value;
    },

    dropdownId: function() {
        if (!this.size()) return;
        var opt = this.get(0).dropdown.selectedOption();
        if (opt) return opt.id;
    },

    dropdownLabel: function() {
        if (!this.size()) return;
        var opt = this.get(0).dropdown.selectedOption();
        if (opt) return opt.title;
    },

    dropdownDisable: function(value) {
        $.each(this, function() {
            this.dropdown.disableOption(value);
        });
    },

    dropdownEnable: function() {
        $.each(this, function() {
            this.dropdown.enableAllOptions();
        });
    }
});
})(jQuery);
