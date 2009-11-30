(function($) {

var t = tt = new Test.SocialCalc();

t.plan(7);

t.runAsync([
    function() {
        t.open_iframe_with_socialcalc("/admin/index.cgi?action=display;page_type=spreadsheet;page_name="+t.gensym()+"#edit", t.nextStep());
    },

    function() {
        t.pass('Left');
        t.pass('Center');
        t.pass('Right');
        t.pass('Justify');
        t.pass('Top');
        t.pass('Middle');
        t.pass('Bottom');
        t.endAsync();
    }
]);

})(jQuery)
