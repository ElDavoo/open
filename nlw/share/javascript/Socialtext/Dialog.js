if (typeof(socialtext) == 'undefined') socialtext = {};
socialtext.dialog = (function($) {
    var dialogs = {};
    var loaded = {};

    var timestamp = (new Date).getTime();
    var _gz = 
        !$.browser.safari && Socialtext.accept_encoding
            && Socialtext.accept_encoding.match(/\bgzip\b/) ? '.gz' : '';

    // Socialtext adapter class for jQuery dialogs
    var Dialog = function(node) {
        this.node = node;
    };
    Dialog.prototype = {
        close: function() { this.node.dialog('destroy') },
        find: function(selector) { return this.node.find(selector) }
    };

    return {
        createDialog: function(opts) {
            var opts = typeof(opts) == 'string' ? { html: opts } : opts;
            var $content = opts.content
                ? $(content)
                : $('<div></div>').html(opts.html);
            $content.dialog($.extend({
                width: 520,
                modal: true
            }, opts));
            if ($.isFunction(opts.callback)) opts.callback();
            return new Dialog($content);
        },

        show: function(name, args) {
            var self = this;
            if (loaded[name]) {
                self.callDialog(name, args);
            }
            else {
                loaded[name] = true;
                var uri = nlw_make_js_path('dialog-' + name + '.js' + _gz);
                $.ajaxSettings.cache = true;
                $.getScript(uri, function() {
                    self.callDialog(name, args);
                });
                $.ajaxSettings.cache = false;
            }
        },

        callDialog: function(name, args) {
            if (!dialogs[name]) throw new Error(name + " didn't register!");
            dialogs[name].call(this, args);
        },

        register: function(name, callback) {
            dialogs[name] = callback;
        },
        
        showResult: function (msg) {
            var $dialog = $('<div></div>').html(msg);
            $('<a class="button" href="#"></a>')
                .text(loc('do.close'))
                .click(function() {
                    $dialog.dialog('destroy');
                    return false;
                })
                .appendTo($dialog.append('<div class="vpad20"></div>'));

            $dialog.dialog({
                title: 'Success',
                width: 400,
                modal: true
            });
        },

        showError: function (msg, callback) {
            this.ShowResult(msg);
            if ($.isFunction(callback)) callback();
        },

        process: function (template, vars) {
            vars = vars || {};
            vars.loc = loc;
            return Jemplate.process(template, vars);
        }
    };
})(jQuery);

// Compat
$.hideLightbox = function() { throw new Error('$.hideLightbox deprecated') }
$.showLightbox = function() { throw new Error('$.showLightbox deprecated') }
$.pauseLightbox = function() { throw new Error('$.pauseLightbox deprecated') }
$.resumeLightbox = function() { throw new Error('$.resumeLightbox deprecated') }
