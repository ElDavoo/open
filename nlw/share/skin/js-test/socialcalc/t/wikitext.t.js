(function($) {

var t = tt = new Test.SocialCalc();

t.plan(4);

t.runAsync([
    function() {
        t.open_iframe_with_socialcalc("/admin/index.cgi?action=display;page_type=spreadsheet;page_name="+t.gensym()+"#edit", t.nextStep());
    },

    function() {
        t.pass('Text to Wikitext');
        t.pass('Richtext to Wikitext');
        t.pass('Wikitext to Richtext');
        t.pass('Wikitext to Text');
        t.endAsync();
    }
]);

})(jQuery)
