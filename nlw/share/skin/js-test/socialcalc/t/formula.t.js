(function($) {

var t = tt = new Test.SocialCalc();

t.plan(4);

t.runAsync([
    function() {
        t.open_iframe_with_socialcalc("/admin/index.cgi?action=display;page_type=spreadsheet;page_name="+t.gensym()+"#edit", t.nextStep());
    },

    function() {
        t.pass('Quick Sum');
        t.pass('Multi-line Input');
        t.pass('Multi-line Apply');
        t.pass('Single-line Input');
        t.endAsync();
    }
]);

})(jQuery)
