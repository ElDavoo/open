(function($) {

var t = tt = new Test.SocialCalc();

t.plan(1);

t.runAsync([
    function() {
        t.open_iframe_with_socialcalc("/admin/index.cgi?action=display;page_type=spreadsheet;page_name="+t.gensym()+"#edit", t.nextStep());
    },

    function() {
        t.pass('Audit');
        t.endAsync();
    }
]);

})(jQuery)
