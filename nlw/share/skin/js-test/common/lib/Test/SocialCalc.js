(function() {

proto = Test.Base.newSubclass('Test.SocialCalc', 'Test.Visual');

proto.open_iframe_with_socialcalc = function(url, callback) {
    var t = this;
    this.open_iframe(url, function() {
        t.wait_for_socialcalc(callback);
    });
}

proto.curCell = function() {
    var t = this;
    if (t.$('#st-spreadsheet-edit #e-cell_A1').is(':visible')) {
        return t.$('#st-spreadsheet-edit #e-cell_A1');
    }
    return t.$('#st-spreadsheet-preview #cell_A1');
}

proto.doCheckCSS = function(attr, value, msg) {
    var t = this;
    return function() {
        t.is(t.curCell().css(attr).replace(/^\s+|\s+$/g, ''), value, msg);
        t.callNextStep();
    };
}

proto.doCheckText = function(text, msg) {
    var t = this;
    return function() {
        t.is(t.curCell().text().replace(/^\s+|\s+$/g, ''), text, msg);
        t.callNextStep();
    };
}


proto.callNextStepOnReady = function() {
    var t = this;
    setTimeout(function(){
        t.poll(function(){
            return(!t.ss.editor.busy);
        }, function(){
            t.callNextStep();
        })
    }, 100);
};

proto.doClick = function(selector) {
    var t = this;
    return function() {
        t.click(selector);
        setTimeout(function() {
            t.callNextStepOnReady();
        }, 500);
    };
};

proto.doExec = function(cmd) {
    var t = this;
    return function() {
        t.ss.editor.EditorScheduleSheetCommands(cmd);
        t.callNextStepOnReady();
    };
};

proto.endAsync = function() {
    var t = this;
    if (! t.asyncId)
        throw("endAsync called out of order");

    var doEndAsync = function() {
        t.builder.endAsync(t.asyncId);
        t.asyncId = 0;
    }

    if (t.$('#st-save-button-link').is(':visible')) {
        t.click('#st-save-button-link');
        t.poll( function() {
            return t.$('#st-display-mode-container', t.win.document).is(':visible')
        }, doEndAsync);
    }
    else {
        doEndAsync();
    }
}

proto.richtextModeIsReady = function () { return true }

proto.wait_for_socialcalc = function(callback) {
    var t = this;
    this.$.poll(
        function() {
            return Boolean(
                t.iframe.contentWindow.SocialCalc &&
                t.iframe.contentWindow.SocialCalc.editor_setup_finished
            );
        },
        function() {
            t.ss = t.iframe.contentWindow.ss;
            t.SocialCalc = t.iframe.contentWindow.SocialCalc;

            callback.apply(t);
        },
        250, 15000
    );
}

})();
