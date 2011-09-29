Socialtext.prototype.dialog = (function($) {
    var dialogs = {};
    var loaded = {};

    var timestamp = (new Date).getTime();

    // Socialtext adapter class for jQuery dialogs
    var Dialog = function(opts) {
        this.show(opts);
    };
    Dialog.prototype = {
        show: function(opts) {
            var self = this;
            // content
            var opts = typeof(opts) == 'string' ? { html: opts } : opts;
            self.node = opts.content
                ? $(content)
                : $('<div></div>').html(opts.html);

            self.node.dialog($.extend({
                width: 520,
                modal: true,
                close: function() { self.close() }
            }, opts));
        },
        close: function() {
            this.node.dialog('destroy').remove();
        },
        find: function(selector) { return this.node.find(selector) },
        showError: function(err) { this.node.find('.error').html(err) },
        disable: function() {
            this.node.parents('.ui-dialog').uiDisable();
        },
        enable: function() {
            this.node.parents('.ui-dialog').uiEnable();
        }
    };

    return {
        createDialog: function(opts) {
            return new Dialog(opts);
        },

        show: function(name, args) {
            var self = this;
            if (loaded[name]) {
                self.callDialog(name, args);
            }
            else {
                loaded[name] = true;
                $.ajaxSettings.cache = true;
                $.ajax({
                    url: st.nlw_make_js_path('dialog-' + name + '.jgz'),
                    dataType: 'script',
                    success: function() {
                        self.callDialog(name, args)
                    },
                    error: function(jqXHR, textStatus, errorThrown) {
                        throw errorThrown;
                    }
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
        
        showResult: function (opts) {
            this.show('simple', {
                title: opts.title || loc('Result'),
                message: opts.message,
                width: 400,
                onClose: opts.onClose
            });
        },

        showError: function (message, onClose) {
            this.show('simple', {
                title: loc('Error'),
                message: '<div class="error">' + message + '</div>',
                width: 400,
                onClose: onClose
            });
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

// Temporary compat
if (typeof(socialtext) == 'undefined') socialtext = {};
socialtext.dialog = Socialtext.prototype.dialog;
