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
    });
    $('#st-tags-addbutton').button().click(function() {
        $('#st-tags-form').submit();
    });
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
        .blur(function () {
            setTimeout(function () {
                $('#st-tags-form').hide();
                $('#st-tags-addlink').show()
            }, 500);
        })
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
}

})(jQuery);
