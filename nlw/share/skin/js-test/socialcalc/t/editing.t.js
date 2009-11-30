(function($) {

var t = tt = new Test.SocialCalc();

t.plan(8);

t.runAsync([
    function() {
        t.open_iframe_with_socialcalc("/admin/index.cgi?action=display;page_type=spreadsheet;page_name="+t.gensym()+"#edit", t.nextStep());
    },

    function() {
        t.pass('Undo');
        t.pass('Redo');
        t.pass('Cut');
        t.pass('Copy');
        t.pass('Paste');
        t.pass('Erase');
        t.pass('Add File');
        t.pass('Add Tag');
        t.endAsync();
    }
]);

})(jQuery)
