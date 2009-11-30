(function($) {

var t = tt = new Test.SocialCalc();

t.plan(3);

t.runAsync([
    function() {
        t.open_iframe_with_socialcalc("/admin/index.cgi?action=display;page_type=spreadsheet;page_name="+t.gensym()+"#edit", t.nextStep());
    },

    function() {
        t.pass('Revision');
        t.pass('Restore Revision');
        t.pass('Edit Revision');
        t.endAsync();
    }
]);

})(jQuery)
