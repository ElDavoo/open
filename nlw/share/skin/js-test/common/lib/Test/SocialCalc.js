(function() {

proto = Test.Base.newSubclass('Test.SocialCalc', 'Test.Visual');

proto.open_iframe_with_socialcalc = function(url, callback) {
    var t = this;
    this.open_iframe(url, function() {
        t.wait_for_socialcalc(callback);
    });
}

proto.doExec = function(cmd) {
    var t = this;
    return function() {
        t.ss.editor.EditorScheduleSheetCommands(cmd);
        setTimeout(function(){
            t.poll(function(){
                return(!t.ss.editor.busy);
            }, function(){
                t.callNextStep();
            })
        }, 100);
    };
};

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
