Socialtext.S3 = true;

function trim(value) {
    var ltrim = /\s*((\s*\S+)*)/;
    var rtrim = /((\s*\S+)*)\s*/;
    return value.replace(rtrim, "$1").replace(ltrim, "$1");
};

function is_reserved_pagename(pagename) {
    if (pagename && pagename.length > 0) {
        var name = nlw_name_to_id(trim(pagename));
        var untitled = nlw_name_to_id(loc('Untitled Page'))
        return name == untitled;
    }
    else {
        return false;
    }
}

function nlw_name_to_id(name) {
    if (name == '')
        return '';
    return encodeURI(
        name.replace(/[^A-Za-z0-9_+]/g, '_') /* For Safari, the similar regex below doesn't work in Safari */
            .replace(/[^A-Za-z0-9_+\u00C0-\u00FF]/g, '_')
            .replace(/_+/g, '_')
            .replace(/^_*(.*?)_*$/g, '$1')
            .replace(/^0$/, '_')
            .replace(/^$/, '_')
            .toLocaleLowerCase()
    );
}

push_onload_function = function (fcn) { jQuery(fcn) }

Socialtext.make_table_sortable = function(table) {
    if (jQuery.browser.msie) { 
        for (var i in table) {
            if (i.match(/^jQuery\d+/)) {
                table.removeAttribute(i);
                jQuery(table).removeAttr(i);
                jQuery('*', table).removeAttr(i);
            }
        }
    }

    if (!table) return;
    if (typeof(table.config) != 'undefined' && table.config != null) {
        // table.config = null;
        $(table).trigger("update");
    }
    else {
        $(table).addClass("sort");
        $(table).tablesorter();

        // Because the tables inside wysiwyg editing area are expected to be
        // changed, we forcibly update it on every sort.
        if (window.wikiwyg &&
            wikiwyg.current_mode.classtype == 'wysiwyg' &&
            $(table).parents("body").get(0) == wikiwyg.current_mode.get_edit_document().body
        ) {
            $(table).bind("sortStart", function() {
                $(this).trigger("update");
            });
        }
    }
}

Socialtext.make_table_unsortable = function(table) {
    if (!table) return;
    if (typeof(table.config) != 'undefined')  {
        try { delete table.config; }
        catch (e) { table.config = null; }
    }
    $(table).removeClass("sort").find("tr:eq(0) td").unbind("click").unbind("mousedown");
}

$(function() {
    setTimeout(function() { $('#contentWarning').hide('slow') }, 10000);

    // Fix the global nav for IE6
    $('#mainNav ul.level2').createSelectOverlap({noPadding: true});

    $('table.sort')
        .each(function() { Socialtext.make_table_sortable(this) });

    $('#st-page-boxes-toggle-link')
        .bind('click', function() {
            var hidden = $('#contentColumns').hasClass('hidebox');
            if (hidden)
                $('#contentColumns').removeClass("hidebox").addClass("showbox");
            else
                $('#contentColumns').removeClass("showbox").addClass("hidebox");
            hidden = !hidden;
            this.innerHTML = hidden ? 'show' : 'hide';
            Cookie.set('st-page-accessories', hidden ? 'hide' : 'show');

            if ($('div#contentLeft').css('overflow') == 'visible') {
                if (hidden) {
                    cl.width(parseInt(cl.css('max-width')));
                }
                else {
                    cl.width(parseInt(cl.css('min-width')));
                }
            }
            
            // Because the content area's height might have changed, repaint
            // the Edit/Comment buttons at the bottom for IE.
            Page._repaintBottomButtons();

            return false;
        });

    $('#st-tags-addlink')
        .bind('click', function () {
            $(this).hide();
            $('#st-tags-addbutton-link').show();
            $('#st-tags-field')
                .val('')
                .show()
                .focus();
            return false;
        })

    $('#st-tags-field')
        .blur(function () {
            setTimeout(function () {
                $('#st-tags-field').hide();
                $('#st-tags-addbutton-link').hide();
                $('#st-tags-addlink').show()
            }, 500);
        })
        .lookahead({
            url: Page.workspaceUrl() + '/tags',
            params: {
                order: 'weighted',
                exclude_from: Socialtext.page_id
            },
            linkText: function (i) {
                return i.name
            },
            onAccept: function (val) {
                Page.addTag(val);
            }
        });
            

    $('#st-tags-form')
        .bind('submit', function () {
            var tag = $('#st-tags-field').val();
            Page.addTag(tag);
            return false;
        });

    $('#st-attachments-uploadbutton').unbind('click').click(function () {
        get_lightbox('attachment', function () {
            $('#st-attachments-attach-list').html('').hide();
            Attachments.showUploadInterface();
        });
        return false;
    });

    $('.extract_attachment').unbind('click').click(function () {
        get_lightbox('attachment', function() {
            $(this).children('img')
                .attr('src', '/static/skin/common/images/ajax-loader.gif');
                Attachments.extractAttachment($(this).attr('name'));
                return false
        });
    });

    $('.delete_attachment').unbind('click').click(function () {
        var self = this
        get_lightbox('attachment', function () {
            Attachments.showDeleteInterface(self);
        });
        return false;
    });

    var _gz = '';

    if (Socialtext.accept_encoding && Socialtext.accept_encoding.match(/\bgzip\b/)) {
        _gz = '.gz';
    }

    var editor_uri = nlw_make_s3_path('/javascript/socialtext-editor.js' + _gz)
        .replace(/(\d+\.\d+\.\d+\.\d+)/,'$1.'+Socialtext.make_time);

    var socialcalc_uri = nlw_make_plugin_path(
        "/socialcalc/javascript/socialtext-socialcalc.js" + _gz
    );
    if (Socialtext.socialcalc_make_time) {
        socialcalc_uri = socialcalc_uri.replace(
            /(\d+\.\d+\.\d+\.\d+)/,
            '$1.' + Socialtext.socialcalc_make_time
        );
    }

    function get_lightbox (lightbox, cb) {
        Socialtext.lightbox_loaded = Socialtext.lightbox_loaded || {};
        if (Socialtext.lightbox_loaded[lightbox]) {
            cb();
        }
        else {
            Socialtext.lightbox_loaded[lightbox] = true;
            var uri = nlw_make_s3_path(
                '/javascript/lightbox-' + lightbox + '.js' + _gz
            ).replace(/(\d+\.\d+\.\d+\.\d+)/,'$1.'+Socialtext.make_time);

            $.ajaxSettings.cache = true;
            $.getScript(uri, cb);
            $.ajaxSettings.cache = false;
        }
    }
    window.get_lightbox = get_lightbox;

    function get_plugin_lightbox (plugin, lightbox, cb) {
        Socialtext.plugin_lightbox_loaded =
            Socialtext.plugin_lightbox_loaded || {};
        if (Socialtext.plugin_lightbox_loaded[lightbox]) {
            cb()
        }
        else {
            var uri = nlw_make_plugin_path(
                '/' + plugin + '/javascript/lightbox-' + lightbox + '.js' + _gz
            ).replace(/(\d+\.\d+\.\d+\.\d+)/,'$1.'+Socialtext.make_time);
            $.ajaxSettings.cache = true;
            $.getScript(uri, cb);
            $.ajaxSettings.cache = false;
        }
    }
    window.get_plugin_lightbox = get_plugin_lightbox;

    $("#st-comment-button-link, #bottomButtons .commentButton")
        .click(function () {
            if ($('div.commentWrapper').length) {
                Page._currentGuiEdit.scrollTo();
                return;
            }

            get_lightbox('comment', function () {
                var ge = new GuiEdit({
                    id: 'contentLeft',
                    oncomplete: function () {
                        Page.refreshPageContent();
                    },
                    onclose: function () {
                        Page._repaintBottomButtons();
                    }
                });
                Page._currentGuiEdit = ge;
                ge.show();
                Page._repaintBottomButtons();
            });

            Page._repaintBottomButtons();
            return false;
        });

    $(".weblog_comment").click(function () {
        var page_id = this.id.replace(/^comment_/,'');
        get_lightbox('comment', function () {
            var ge = new GuiEdit({
                page_id: page_id,
                id: 'content_'+page_id,
                oncomplete: function () {
                    $.get(Page.pageUrl(page_id), function (html) {
                        $('#content_'+page_id).html(html);
                    });
                }
            });
            ge.show();
        });
        return false;
    });

    $("#st-pagetools-email").click(function () {
        get_lightbox('email', function () {
            var Email = new ST.Email;
            Email.show();
        });
        return false;
    });

    $('#st-edit-warning-help').click(function() {
        get_lightbox('edit_warning_help', function() {
            $("body").append(Jemplate.process("edit_warning_help.tt2", {}));
            jQuery.showLightbox({
                speed: 0,
                content: "#st-edit-warning-help-inline",
                close: "#st-edit-warning-help-inline .close",
                callback: function() {
                    //$.hideLightbox();
                }
            });
        });
        return false;
    });

    //index.cgi?action=duplicate_popup;page_name=[% page.id %]
    $("#st-pagetools-duplicate").click(function () {
        get_lightbox('duplicate', function () {
            var duplicate = new ST.Duplicate;
            duplicate.duplicateLightbox();
        });
        return false;
    });

    $("#st-pagetools-rename").click(function () {
        get_lightbox('rename', function () {
            var rename = new ST.Rename;
            rename.renameLightbox();
        });
        return false;
    });

    var page_lock_rollover = function() {
        var img = $(this).find('img');
        var src = img.attr('src');
        var path = '/static/skin/s3/images/';

        new_src = ( src == path + 'lock-locked.png' )
            ? path + 'lock-unlocked.png'
            : path + 'lock-locked.png';

        img.attr('src', new_src);
    }

    $('#st-admin-lock-link').mouseover(page_lock_rollover);
    $('#st-admin-lock-link').mouseout(page_lock_rollover);
    $('#st-admin-lock-link').click(function() {
        $(this).unbind('mouseover');
        $(this).unbind('mouseout');

        var img = $(this).find('img');
        img.attr('src', '/static/skin/common/images/ajax-loader.gif');
    });

    //index.cgi?action=copy_to_workspace_popup;page_name=[% page.id %]')
    $("#st-pagetools-copy").click(function () {
        get_lightbox('copy', function () {
            var copy = new ST.Copy;
            copy.copyLightbox();
        });
        return false;
    });

    $("#st-create-content-link, .incipient").unbind("click").click(function (e, data) {
        var $anchor = jQuery(this);

        var title;

        if ($anchor.hasClass('incipient')) {
            var match = $anchor.attr('href').match(/page_name=([^;#]+)/);
            if (match) {
                title = match[1];
            }
            else {
                title = $anchor.text();
            }
        }
        else if (data) {
            title = data.title
        }

        get_lightbox('create_content', function () {
            var create_content = new ST.CreateContent;
            create_content.show();
            if (title) {
                create_content.set_incipient_title(title);
            }
        });
        return false;
    });

    $("#st-pagetools-delete").click(function () {
        get_lightbox('delete', function () {
            var del = new ST.Delete;
            del.deleteLightbox();
        });
        return false;
    });

    if (location.hash.toLowerCase() == '#new_page' || location.search.toLowerCase() == '?_p=new_page') {
        $('#st-create-content-link').click();
    }

    if (location.hash.toLowerCase() == '#new_page') {
        $('#st-create-content-link').click();
    }

    // Currently, the pre edit hook will check for an edit contention.
    Socialtext.pre_edit_hook = function (wikiwyg_launcher) {
        jQuery.ajax({
            type: 'GET',
            url: location.pathname,
            data: {
                action: 'edit_check',
                page_name: Socialtext.wikiwyg_variables.page.title
            },
            dataType: 'json',
            success: function(data) {
                if (data.user_link) {
                    get_lightbox("edit_check", function() {
                        $("body").append(
                            Jemplate.process("edit_check.tt2", data)
                        );

                        jQuery.showLightbox({
                            speed: 0,
                            content: "#st-edit-check",
                            close: "#st-edit-check .close",
                            callback: function() {
                                $('#bootstrap-loader').hide();

                                var bootstrap = false;
                                $("#st-edit-check .continue")
                                    .one("click", function() {

                                    $.hideLightbox();
                                    wikiwyg_launcher();
                                });

                                $("#lightbox")
                                    .one("lightbox-unload", function() { });
                            }
                        });

                    });
                }
                else {
                    wikiwyg_launcher();
                }
            }
        });


    }

    Socialtext._show_loading_animation = function () {
        $('#bootstrap-loader')
            .css('position', 'absolute')
            .css('float', 'none')
            .css('left', 
                $('#st-editing-tools-edit li:last').offset().left + 120 + 'px')
            .show();
    }

    Socialtext.load_editor = function () {
        $.ajaxSettings.cache = true;
        if (Socialtext.page_type == 'spreadsheet' && Socialtext.wikiwyg_variables.hub.current_workspace.enable_spreadsheet) {
            $.getScript(socialcalc_uri, function () {
                Socialtext.start_spreadsheet_editor();
                $('#bootstrap-loader').hide();
            });
        }
        else {
            $.getScript(editor_uri);

            if (!$.browser.msie) {
                var lnk = $('link[rel=stylesheet][media=screen]');
                lnk.clone()
                    .attr('href', nlw_make_s3_path('/css/wikiwyg.css')
                        .replace(/(\d+\.\d+\.\d+\.\d+)/, '$1.' + Socialtext.make_time)
                    )
                    .attr('media', 'wikiwyg')
                    .appendTo('head');
            }
        }
        $.ajaxSettings.cache = false;
        return false;
    }

    $("#st-edit-button-link,#st-edit-actions-below-fold-edit, #bottomButtons .editButton")
        .one("click", function(){
	    Socialtext._show_loading_animation();

	    setTimeout(
		function() {
		    if (editorIntervalId) {
			clearInterval(editorIntervalId);
			Socialtext.load_editor();
		    }
		}, 90000 // max. 90sec wait before we start editing
	    );

	    var editorIntervalId = setInterval(function() {
		if (Socialtext.body_loaded) {
		    clearInterval(editorIntervalId);
		    editorIntervalId = 0;
		    Socialtext.load_editor();
		}
	    }, 100); // Poll every 0.1 seconds until all pictures finish loading
	});

    if (Socialtext.double_click_to_edit) {
        var double_clicker = function() {
            jQuery("#st-edit-button-link").click();
        };
        jQuery("#st-page-content").one("dblclick", double_clicker);
    }

    $('#st-listview-submit-pdfexport').click(function() {
        if (!$('.st-listview-selectpage-checkbox:checked').size()) {
            alert(loc("You must check at least one page in order to create a PDF."));
        }
        else {
            $('#st-listview-action').val('pdf_export')
            $('#st-listview-filename').val(Socialtext.wiki_id + '.pdf');
            $('#st-listview-form').submit();
        }
        return false;
    });

    $('#st-listview-submit-rtfexport').click(function() {
        if (!$('.st-listview-selectpage-checkbox:checked').size()) {
            alert(loc("You must check at least one page in order to create a Word document."));
        }
        else {
            $('#st-listview-action').val('rtf_export')
            $('#st-listview-filename').val(Socialtext.wiki_id + '.rtf');
            $('#st-listview-form').submit();
        }
        return false;
    });

    $('#st-listview-selectall').click(function () {
        var self = this;
        $('input[type=checkbox]').each(function() {
            if ( ! $(this).attr('disabled') ) {
                $(this).attr('checked', self.checked);
            }
        });
        return true;
    });

    $('input[name=homepage_is_weblog]').click(function () {
        $('input[name=homepage_weblog]')
            .attr('disabled', Number($(this).val()) ? false : true)
    });

    $('input[name=homepage_weblog]').lookahead({
        url: function () { return Page.workspaceUrl() + '/tags' },
        filterValue: function (val) {
            return val + '.*(We)?blog$';
        },
        linkText: function (i) { return i.name }
    });

    Socialtext.ui_expand_on = function() {
        $("#st-edit-pagetools-expand,#st-pagetools-expand").attr("title", loc("Return edit area to normal view")).text(loc("Normal")).addClass("contract");
        $('#st-edit-mode-container, #mainWrap').addClass("expanded");

        $(window).trigger("resize");

        if ($('body').css('overflow') != 'hidden') {
            Socialtext._originalBodyOverflow = $('body').css('overflow');
            $('body').css('overflow', 'hidden');
        }

        if ($('html').css('overflow') != 'hidden') {
            Socialtext._originalHTMLOverflow = $('html').css('overflow');
            $('html').css('overflow', 'hidden');
        }

        window.scrollTo(0, 0);
        return false;
    };
    Socialtext.ui_expand_off = function() {
        $("#st-edit-pagetools-expand,#st-pagetools-expand").attr("title", loc("Expand edit area to fill browser window")).text(loc("Expand")).removeClass("contract");
        $('#st-edit-mode-container, #mainWrap').removeClass("expanded");

        $("iframe#st-page-editing-wysiwyg").width( $('#st-edit-mode-view').width() - 48 );

        $(window).trigger("resize");
        $('html').css('overflow', Socialtext._originalHTMLOverflow || 'auto');
        $('body').css('overflow', Socialtext._originalBodyOverflow || 'auto');
        return false;
    };
    Socialtext.ui_expand_setup = function() {
        if (Cookie.get("ui_is_expanded"))
            return Socialtext.ui_expand_on();
    };
    Socialtext.ui_expand_toggle = function() {
        if (Cookie.get("ui_is_expanded")) {
            Cookie.del("ui_is_expanded");
            return Socialtext.ui_expand_off();
        }
        else {
            Cookie.set("ui_is_expanded", "1");
            return Socialtext.ui_expand_on();
        }
    };
    $("#st-pagetools-expand").click(Socialtext.ui_expand_toggle);

    function makeWatchHandler (pageId) { return function(){
        var self = this;
        if ($(this).hasClass('on')) {
            $.get(
                location.pathname + '?action=remove_from_watchlist'+
                ';page=' + pageId +
                ';_=' + (new Date()).getTime(),
                function () {
                    var text = loc("Watch");
                    $(self).attr('title', text).text(text);
                    $(self).removeClass('on');
                }
            );
        }
        else {
            $.get(
                location.pathname + '?action=add_to_watchlist'+
                ';page=' + pageId +
                ';_=' + (new Date()).getTime(),
                function () {
                    var text = loc('Stop Watching');
                    $(self).attr('title', text).text(text);
                    $(self).addClass('on');
                }
            );
        }
    }; }

    // Watch handler for single-page view
    $('#st-watchlist-indicator').click(makeWatchHandler(Socialtext.page_id));

    // Watch handler for watchlist view
    $('td.listview-watchlist a[id^=st-watchlist-indicator-]').each(function(){
        $(this).click(
            makeWatchHandler(
                $(this).attr('id').replace(/^st-watchlist-indicator-/, '')
            )
        );
    });

    if ( Socialtext.new_page && Socialtext.page_title != loc("Untitled Page") && !location.href.toString().match(/action=display;/)) {
        $("#st-create-content-link").trigger("click", { title: Socialtext.page_title })
    }
    else if (Socialtext.new_page||
        Socialtext.start_in_edit_mode ||
        location.hash.toLowerCase() == '#edit' ) {
        setTimeout(function() {
            $("#st-edit-button-link").click();
        }, 500);
    }

    var cl = $('div#contentLeft');
    if (cl.length) {
        var adjustContentLeftOverflow = function () {
            var cl = $('div#contentLeft');
            if (cl.get(0).offsetHeight > cl.get(0).clientHeight) {
                var clWidth = $('#contentLeft').get(0).scrollWidth;
                var crWidth = $('#contentRight').width();

                $('#mainWrap').width( clWidth + crWidth + 50 );

                cl.css('min-width', clWidth + 'px');
                cl.css('max-width', (clWidth + crWidth) + 'px');

                if ($('div#contentColumns.hidebox').length) {
                    cl.width(clWidth + crWidth);
                }
                else {
                    cl.width(clWidth);
                }

                cl.addClass('overflowVisible');

                $('#contentRight').css('width', crWidth + 'px');
                $('#contentRight').css('max-width', crWidth + 'px');

                Page._repaintBottomButtons();
            }
        };
        adjustContentLeftOverflow();
        $(window).resize(adjustContentLeftOverflow);
    }

    // Find the field to focus
    var focus_field = Socialtext.info.focus_field[ Socialtext.action ];
    if (! focus_field && typeof(focus_field) == 'undefined') {
        focus_field = Socialtext.info.focus_field.default_field;
    }
    if (focus_field)
        jQuery(focus_field).select().focus();
});
