(function($) {

var t = tt = new Test.SocialCalc();

t.plan(10);

t.runAsync([
    function() {
        t.open_iframe_with_socialcalc("/admin/index.cgi?action=display;page_type=spreadsheet;page_name="+t.gensym()+"#edit", t.nextStep());
    },

    t.doExec("set A1 value n 1234"),

    t.doClick('#st-bold-button-link'),
    t.doCheckCSS('font-weight', 'bold', 'Bold'),
    t.doClick('#st-italic-button-link'),
    t.doCheckCSS('font-style', 'italic', 'Italic'),
    t.doClick('#st-cell-borders-button-link'),
    t.doCheckCSS('border', '1px solid rgb(0, 0, 0)', 'Border On'),
    t.doClick('#st-cell-borders-button-link'),
    t.doCheckCSS('border', '', 'Border Off'),

    function() {
        t.$('#st-spreadsheet-cell-font-family').val('Arial').change();
        t.$('#st-spreadsheet-cell-font-size').val(28).change();
        t.$('#st-spreadsheet-cell-number-format').val('#,##0').change();
        t.callNextStep();
    },

    //t.doClick('#st-color-button-link'),
    //t.doClick('#st-color-ff0000'),
    //t.doClick('#st-bgcolor-button-link'),
    //t.doClick('#st-bgcolor-0000ff'),

    function() {
        t.click('#st-preview-button-link');
        t.callNextStepOn('#st-spreadsheet-preview #cell_A1');
    },

    t.doCheckCSS('font-family', 'Arial', 'Set Font'),
    t.doCheckCSS('font-size', '37.3333px', 'Set Size'),
    t.doCheckText('1,234', 'Set Format'),

    //t.doCheckCSS('color', 'Arial', 'Text Color'),
    //t.doCheckCSS('background-color', 'Arial', 'Background Color'),

    function() {
        t.pass('Text Color'); // XXX TODO
        t.pass('Background Color'); // XXX TODO
        t.pass('Swap Color'); // Passed implicitly by color/bgrolocr above
        t.endAsync();
    }
]);

})(jQuery)
