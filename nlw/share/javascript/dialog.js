Socialtext.Dialog = (function($) {
    var dialogs = [];
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
        Create: function(opts) {
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

        Load: function(name, cb) {
            if (loaded[name]) {
                cb();
            }
            else {
                loaded[name] = true;
                var uri = nlw_make_js_path('dialog-' + name + '.js' + _gz);
                $.ajaxSettings.cache = true;
                $.getScript(uri, cb);
                $.ajaxSettings.cache = false;
            }
        },
        
        ShowResult: function (msg) {
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

        ShowError: function (msg, callback) {
            this.ShowResult(msg);
            if ($.isFunction(callback)) callback();
        },

        Process: function (template, vars) {
            vars = vars || {};
            vars.loc = loc;
            return Jemplate.process(template, vars);
        }
    };
})(jQuery);

// Compat
$.hideLightbox = $.noop;
$.showLightbox = Socialtext.Dialog.Create;
$.pauseLightbox = function() { throw new Error('unimplemented') }
$.resumeLightbox = function() { throw new Error('unimplemented') }
