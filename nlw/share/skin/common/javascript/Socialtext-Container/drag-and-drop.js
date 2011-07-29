/* {bz: 5176}: Add support for touch-based devices to $.draggable */
/* This must be loaded after jquery.ui.ipad.altfix.js. */

$(function () {
    var newIframeSrc = null;
    var options = {
        items: 'li.draggable:not(.fixed)',
        cancel: 'li:not(.draggable), .wiki li.draggable',
        handle: '.widgetHeader *',
        zIndex: 10000,
        placeholder: 'placeholder',
        tolerance: 'tolerance',
        start: function (e,el) {
            var iframe = $('iframe', el.item).get(0);
            if (iframe) {
                try {
                    newIframeSrc = $(iframe.contentWindow).data('new_iframe_src');
                }
                catch(e) {}
            }
            el.item.width(el.helper.parent().width());
            el.placeholder.height(el.item.height());
        },
        stop: function (e, el) {
            // {bz: 1641} Workaround a FF bug where the iframe forgets its src
            var iframe = $('iframe', el.item).get(0);
            if (iframe) {
                var loc;
                try {
                    loc = iframe.contentWindow.location;
                }
                catch(e) {}
                if (loc) {
                    loc.href = newIframeSrc || iframe.src;
                }
            }

            el.item.width('100%');
            gadgets.container.fixGadgetTitles();

            // Hack to fix {bz: 3802} - after we finish dragging, we need to
            // reset the sameDomain hash in gadgets.rpc so that it doesn't try
            // to call functions in the old deleted iframe
            gadgets.rpc.clearSameDomain();

            setTimeout(function () {
                gadgets.container.updateLayout();
                if ($.fn.addTouch) {
                    $('li.draggable:not(.fixed) .widgetHeader').addTouch();
                }
            },1000);
        }
    }

    $("#col0.draggable").sortable($.extend({
        connectWith: ["#col1.draggable", "#col2.draggable"]
    }, options)); 
    $("#col1.draggable").sortable($.extend({
        connectWith: ["#col0.draggable", "#col2.draggable" ]
    }, options));
    $("#col2.draggable").sortable($.extend({
        connectWith: ["#col0.draggable", "#col1.draggable" ]
    }, options));

    if ($.fn.addTouch) {
        $('li.draggable:not(.fixed) .widgetHeader').addTouch();
    }
});
