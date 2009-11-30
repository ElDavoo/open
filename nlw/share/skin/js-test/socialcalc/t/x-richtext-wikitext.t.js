(function($) {

var t = tt = new Test.SocialCalc();

t.plan(9);

t.runAsync([
    function() {
        t.open_iframe_with_socialcalc("/admin/index.cgi?action=display;page_type=spreadsheet;page_name="+t.gensym()+"#edit", t.nextStep());
    },

    function() {
        t.pass('Make an image WAFL. Make the cell rich text. See image?');
        t.pass('Move the cursor away. Now put it back. See image in cell?');
        t.pass('...See image in input focus?');
        t.pass('Now make it wikitext. See wafl?');
        t.pass('Copy/paste cell to next row down. See wafl?');
        t.pass('Make cell rich text. See image?');
        t.pass('copy/paste cell to next row down. See wafl?');
        t.pass('Type _*yoyoyo*_ into cell. Click on rich text. See bold, italic?');
        t.pass('Move cell to right. Move cell back. See bold, italic?');
        t.endAsync();
    }
]);

})(jQuery)
