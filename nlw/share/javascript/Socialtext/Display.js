(function($) {

Socialtext.prototype.setupPageHandlers = function() {
    // Tools menu -- collapse
    $('.tools .expanded').live('click', function() {
        $(this).hide();
        $(this).siblings('.subtools').hide();
        $(this).siblings('.collapsed').show();
        return false;
    });
    // Tools menu -- expand
    $('.tools .collapsed').live('click', function() {
        $(this).hide();
        $(this).siblings('.subtools').show();
        $(this).siblings('.expanded').show();
        return false;
    });

    // Tags
    st.page.renderTags();

    $('#st-tags-addlink').button().click(function() {
        $(this).hide();
        $('#st-tags-form').show();
        $('#st-tags-field').val('').focus();
        $('#st-tags-field').unbind('blur').blur(function () {
            setTimeout(function () {
                $('#st-tags-form').hide();
                $('#st-tags-addlink').show();
            }, 500);
        })
    });

    $('#st-tags-plusbutton-link')
        .button({ label: '+' })
        .click(function() { $('#st-tags-form').submit() });

    $('#st-tags-form')
        .bind('submit', function () {
            var tag = $('#st-tags-field').val();
            st.page.addTag(tag);
            return false;
        });
    $('#st-tags-plusbutton-link').click(function() {
        $('#st-tags-form').submit();
    });
    $('#st-tags-field')
        .lookahead({
            url: '/data/workspaces/' + st.workspace.name + '/tags',
            params: {
                order: 'weighted',
                exclude_from: st.page.id
            },
            linkText: function (i) {
                return i.name
            },
            onAccept: function (val) {
                st.page.addTag(val);
            }
        });

    // Attachments
    st.attachments.renderAttachments();

    $('#st-attachments-uploadbutton').button().click(function () {
        socialtext.dialog.show('attachments-upload');
        return false;
    });

    // Edit
    $('#st-edit-button-link').button().click(function() {
        var $button = $(this);
        $button.button('disable');
        $.getScript(st.nlw_make_js_path('socialtext-ckeditor.jgz'), function() {
            Socialtext.start_xhtml_editor();
            $button.button('enable');
        });
        return false;
    });

    if (st.page.is_new
        && st.page.title != loc("page.untitled")
        && st.page.title != loc("sheet.untitled")
        && !location.href.toString().match(/action=display;/)
        && !/^#draft-\d+$/.test(location.hash)
    ) {
        $("#st-create-content-link").trigger("click", {
            title: st.page.title
        })
    }
    else if (st.page.is_new || st.start_in_edit_mode
            || location.hash.toLowerCase() == '#edit') {
        setTimeout(function() {
            $("#st-edit-button-link").click();
        }, 500);
    }

    // Comments
}

})(jQuery);
