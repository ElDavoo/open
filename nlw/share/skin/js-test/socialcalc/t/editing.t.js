(function($) {

var t = tt = new Test.SocialCalc();

t.plan(9);

var doCheckText = function(text, msg) {
    return function() {
        t.is(t.$('#st-spreadsheet-edit #e-cell_A1').text().replace(/\s/g, ''), text, msg);
        t.callNextStep();
    };
}

t.runAsync([
    function() {
        t.open_iframe_with_socialcalc("/admin/index.cgi?action=display;page_type=spreadsheet;page_name="+t.gensym()+"#edit", t.nextStep());
    },

    t.doExec("set A1 text t test"),
    t.doClick('#st-undo-button-link'),
    doCheckText('', 'Undo'),
    t.doClick('#st-redo-button-link'),
    doCheckText('test', 'Redo'),
    t.doClick('#st-cut-button-link'),
    doCheckText('', 'Cut'),
    t.doClick('#st-paste-button-link'),
    doCheckText('test', 'Paste (from Cut)'),
    t.doClick('#st-copy-button-link'),
    doCheckText('test', 'Copy'),
    t.doClick('#st-erase-button-link'),
    doCheckText('', 'Erase'),
    t.doClick('#st-paste-button-link'),
    doCheckText('test', 'Paste (from Copy)'),
    t.doClick('#st-upload-button-link'),

    function() {
        t.callNextStepOn('#st-attachments-attachinterface');
    },

    function() {
        t.pass('Add File');
        t.click('#st-attachments-attach-closebutton');
        t.callNextStepOn('#st-attachments-attachinterface', ':hidden');
    },

    t.doClick('#st-tag-button-link'),

    function() {
        t.callNextStepOn('#st-tagqueue-interface');
    },

    function() {
        t.pass('Add Tag');
        t.click('#st-tagqueue-close');
        t.endAsync();
    }
]);

})(jQuery)
