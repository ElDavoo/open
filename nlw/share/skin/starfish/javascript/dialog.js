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
            $content.dialog({
                title: opts.title || '',
                width: opts.width || 520,
                height: opts.height || 'auto',
                modal: true
            });
            if ($.isFunction(opts.callback)) opts.callback();
            return new Dialog($content);
        },

        Load: function(name, cb) {
            if (loaded[name]) {
                cb();
            }
            else {
                loaded[name] = true;
                var uri = nlw_make_static_path(
                    '/skin/starfish/javascript/dialog-' + name + '.js' + _gz
                );
                if (Socialtext.dev_env) {
                    uri = uri.replace(/(\d+\.\d+\.\d+\.\d+)/,'$1.'+timestamp);
                }

                $.ajaxSettings.cache = true;
                $.getScript(uri, cb);
                $.ajaxSettings.cache = false;
            }
        },
        
        ShowResult: function (msg) {
            Socialtext.dialog.load('result', function() {
                var result = new ST.WidgetsAdminResult;
                result.showResult(loc('info.success'), msg);
            });
        },

        ShowError: function (msg, callback) {
            Socialtext.dialog.load('simple', function() {
                errorLightbox(msg, callback);
            });
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
$.showLightbox = Socialtext.Dialog.Show;
$.pauseLightbox = function() { throw new Error('unimplemented') }
$.resumeLightbox = function() { throw new Error('unimplemented') }
