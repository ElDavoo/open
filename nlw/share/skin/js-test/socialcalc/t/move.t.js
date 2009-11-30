(function($) {

var t = tt = new Test.SocialCalc();

t.plan(16);

t.runAsync([
    function() {
        t.open_iframe_with_socialcalc("/admin/index.cgi?action=display;page_type=spreadsheet;page_name="+t.gensym()+"#edit", t.nextStep());
    },

    function() {
        t.pass('Fill Down');
        t.pass('Fill Right');
        t.pass('Insert Row Below');
        t.pass('Insert Row Above');
        t.pass('Insert Col Left');
        t.pass('Insert Col Right');
        t.pass('Move Row Down');
        t.pass('Move Row Up');
        t.pass('Move Col Left');
        t.pass('Move Col Right');
        t.pass('Delete Row');
        t.pass('Delete Col');
        t.pass('Merge Cell');
        t.pass('Unmerge Cell');
        t.pass('Mark Range');
        t.pass('Move Paste');
        t.endAsync();
    }
]);

})(jQuery)
