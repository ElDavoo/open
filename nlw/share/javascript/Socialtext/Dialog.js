if (typeof(socialtext) == 'undefined') socialtext = {};
socialtext.dialog = (function($) {
    var dialogs = {};
    var loaded = {};

    var timestamp = (new Date).getTime();
    var _gz = 
        !$.browser.safari && Socialtext.accept_encoding
            && Socialtext.accept_encoding.match(/\bgzip\b/) ? '.gz' : '';

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
            this.node.find('iframe').attr('src', '/static/html/blank.html');
            this.node.dialog('destroy');
        },
        find: function(selector) { return this.node.find(selector) },
        showError: function(err) { this.node.find('.error').html(err) },
        disable: function() {
            // image is 16x16
            this.img = $('<div></div>')
                .addClass('dialogDisabled')
                .height(this.node.height())
                .width(this.node.width())
                .css({ top: '40px', left: '10px' })
                .insertAfter(this.node);
            this.node.addClass('opaque');
        },
        enable: function() {
            if (this.img) {
                this.img.remove();
                this.node.removeClass('opaque');
            }
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
                    url: st.nlw_make_js_path('dialog-' + name + '.js' + _gz),
                    dataType: 'script',
                    success: function() {
                        console.log('success');
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
