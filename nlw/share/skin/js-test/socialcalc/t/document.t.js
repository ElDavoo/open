(function($) {

var t = tt = new Test.SocialCalc();

t.plan(5);

t.runAsync([
    function() {
        t.open_iframe_with_socialcalc("/admin/index.cgi?action=display;page_type=spreadsheet;page_name="+t.gensym()+"#edit", t.nextStep());
    },

    t.doExec("set A1 text t test"),

    function() {
        t.click('#st-preview-button-link');
        t.callNextStepOn('#st-spreadsheet-preview #cell_A1');
    },

    function() {
        t.is(t.$('#st-spreadsheet-preview #cell_A1').text(), 'test', 'Preview');
        t.click('#st-preview-button-link');
        t.callNextStepOn('#st-spreadsheet-edit #e-cell_A1');
    },

    function() {
        t.ss.editor.StatusCallback.Test = {
            func: function (editor, status, arg) {
                if (status == 'calcfinished') {
                    t.pass('Refresh');
                    t.callNextStep();
                }
            }
        };

        t.is(t.$('#st-spreadsheet-edit #e-cell_A1').text(), 'test', 'Edit More');
        t.click('#st-recalc-button-link');
    },

    function() {
        t.win.confirm = function() {
            t.pass('Cancel');
            t.callNextStep(1);
            return false;
        };
        t.click('#st-cancel-button-link');
    },

    function() {
        t.click('#st-save-button-link');
        t.callNextStepOn('#st-display-mode-container');
    },

    function() {
        t.pass('Save');
        t.endAsync();
    }
]);

})(jQuery)
