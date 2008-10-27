(function($) {

var t = new Test.Visual();

t.plan(1);

t.checkRichTextSupport();

t.runAsync([
    function() {
        t.open_iframe("/admin/?action=new_page", t.nextStep(15000));
    },
            
    function() { 
        t.$('#st-newpage-pagename-edit').val('bz_1318_'+Math.random());
        t.$('#st-newpage-pagename-edit').focus();
        t.$('a[do=do_widget_link2_hyperlink]').click();

        t.callNextStep(1500);
    },
            
    function() { 
        t.$('#web-link-text').val('Test');
        t.$('#web-link-destination').val('http://socialtext.com/');
        t.$('#add-a-link-form').submit();
        
        t.callNextStep(3000);
    },
            
    function() { 
        var href = $(
            t.$('#st-page-editing-wysiwyg').get(0).contentWindow.document.documentElement
        ).find('a[href=http://socialtext.com/]');

        t.ok(
            href.length,
            "Creating a new link on an empty page should work"
        );

        t.$('#st-save-button-link').click();
        t.callNextStep(3000);

    },
            
    function() { 
        t.endAsync();
    }
]);

})(jQuery);
