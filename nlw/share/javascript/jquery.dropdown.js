(function($){

$.fn.extend({
    dropdown: function(options) {
        if (window.st && window.st.UA_is_Selenium) { return this; }

        this.selectmenu({
            style: 'dropdown',
            width: 'auto'
        });

        var $menu = this.next()
        if (options && options.style) {
            $menu.css(options.style);
        }

        $menu.find('.ui-selectmenu-icon').html('&nbsp;&#9662;');
        
        // Focusing the link puts a weird border around it, so let's
        // not allow that
        $menu.focus(function() { $(this).blur(); return false });

        return this;
    },
    dropdownSelectValue: function(value) {
        this.find('option').removeAttr('selected');
        this.find('option[value="'+value+'"]')
            .attr('selected', 'selected')
            .click();
    }
});
})(jQuery);
