(function($){

if (typeof(Socialtext) == 'undefined') Socialtext = {};
Socialtext.Base = function() {};

Socialtext.Base.prototype = {
    error: '',

    errorCallback: function(callback) {
        var self = this;
        return function(xhr, textStatus, errorThrown) {
            self.error = xhr ? xhr.responseText : errorThrown;
            if (callback)
                callback({error: self.error});
            else 
                alert(self.error);
        };
    },

    successCallback: function(callback) {
        self.error = '';
        return function(data) { callback({ data: data }) };
    },

    /**
     * run several operations asynchronously
     *
     * takes an array of jobs, each is required to take a callback parameter
     * and call the callback after the operation is completed
     */
    runAsynch: function(jobs, callback) {
        var self = this;
        var runJob = function() {
            var job = jobs.shift();
            if (!job) { // done
                callback();
                return;
            }
            job(function(res) {
                if (self.error) {
                    callback();
                }
                else {
                    runJob();
                }
            });
        };
        runJob();
    }
}

})(jQuery);
