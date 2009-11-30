(function($) {

var t = tt = new Test.SocialCalc();

t.plan(9);

t.runAsync([
    function() {
        t.open_iframe_with_socialcalc("/admin/index.cgi?action=display;page_type=spreadsheet;page_name="+t.gensym()+"#edit", t.nextStep());
    },

    function() {
        t.pass('Bold');
        t.pass('Italic');
        t.pass('Text Color');
        t.pass('Background Color');
        t.pass('Swap Color');
        t.pass('Toggle Borders');
        t.pass('Set Font');
        t.pass('Set Size');
        t.pass('Set Format');
        t.endAsync();
    }
]);

})(jQuery)
