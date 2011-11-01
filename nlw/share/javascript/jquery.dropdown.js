(function($){

$.fn.extend({
    dropdown: function(options) {
        if (window.st && window.st.UA_is_Selenium) { return this; }

        this.selectmenu($.extend({
            wrapperElement: '<span />',
            style: 'dropdown',
            width: 'auto'
        }, options));

        // Get the menu
        var $menu = this.next()

        // Change the arrow icon to be a triangle rather than an image
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
