(function ($) {

Socialtext.Page = function(opts) {
    $.extend(this, opts);
};

Socialtext.Page.prototype = {
    /**
     * Tagging
     */
    taguri: function (tag) {
        return this.uri() + '/tags/' + encodeURIComponent(tag);
    },

    uri: function() {
        return '/data/workspaces/' + st.workspace.name + '/pages/' + this.id;
    },

    addTag: function (tag) {
        var self = this;
        $.ajax({
            type: "PUT",
            url: self.taguri(tag),
            // {bz: 4588}: Use an non-empty payload to avoid
            // "411 Length required"
            data: { '': '' },
            complete: function (xhr) {
                self.refreshTags();
                $('#st-tags-field').val('');
            }
        });
    },

    delTag: function (tag) {
        var self = this;
        $.ajax({
            type: "DELETE",
            url: self.taguri(tag),
            complete: function () {
                self.refreshTags();
            }
        });
    },

    renderTags: function() {
        var self = this;
        $('#st-tags-listing').html(
            Jemplate.process('page/tags.tt2', {
                tags: self.tags
            })
        );
        $('#st-tags-listing .delete_icon').click(function() {
            $(this).attr('src', nlw_make_static_path('/images/ajax-loader.gif'));
            self.delTag($(this).siblings('.tag_name').text());
            return false;
        });
    },

    refreshTags: function () {
        var self = this;
        $.ajax({
            url: self.uri() + '/tags?order=alpha',
            cache: false,
            dataType: 'json',
            success: function (tags) {
                self.tags.sorted_tags = tags;
                self.renderTags(); 
            }
        });
    },

    /**
     * Old functions
     */

    // args: (ws,page) or (page_in_current_workspace)

    restApiUri: function () {
        return Page.pageUrl.apply(this, arguments);
    },

    cgiUrl: function () {
        return '/' + Socialtext.wiki_id + '/';
    },

    _repaintBottomButtons: function() {
        $('#bottomButtons').html($('#bottomButtons').html());
        Avatar.createAll();
        $('#st-edit-button-link-bottom').click(function(){
            $('#st-edit-button-link').click();
            return false;
        });
        $('#st-comment-button-link-bottom').click(function(){
            $('#st-comment-button-link').click();
            return false;
        });
    },

    setPageContent: function(html) {
        $('#st-page-content').html(html);
    
        // We may not yet have an edit window, and it may not have finished
        // initialization even if we do.  So ignore all errors here.
        try {
            var iframe = $('iframe#st-page-editing-wysiwyg').get(0);
            iframe.contentWindow.document.body.innerHTML = html;
        } catch (e) {};

        // For MSIE, force browser reflow of the bottom buttons to avoid {bz: 966}.
        Page._repaintBottomButtons();

        // Repaint after each image finishes loading since the height
        // would've been changed.
        $('#st-page-content img').load(function() {
            Page._repaintBottomButtons();
        });
    },

    refreshPageContent: function (force_update) {
        var self = this;
        if (self.page_type == 'spreadsheet') return false;

        $.ajax({
            url: this.uri(),
            data: {
                link_dictionary: 's2',
                verbose: 1,
                iecacheworkaround: (new Date).getTime()
            },
            async: false,
            cache: false,
            dataType: 'json',
            success: function (data) {
                self.html = data.html;
                var newRev = data.revision_id;
                var oldRev = Socialtext.revision_id;
                if ((oldRev < newRev) || force_update) {
                    Socialtext.wikiwyg_variables.page.revision_id =
                        Socialtext.revision_id = newRev;

                    // By this time, the "edit_wikiwyg" Jemplate had already
                    // finished rendering, so we need to reach into the
                    // bootstrapped input form and update the revision ID
                    // there, otherwise we'll get a bogus editing contention.
                    $('#st-page-editing-revisionid').val(newRev);
                    $('#st-rewind-revision-count').html(newRev);

                    rev_string = loc('page.revisions=count', data.revision_count);
                    $('#controls-right-revisions').html(rev_string);
                    $('#bottom-buttons-revisions').html(rev_string);
                    $('#update-attribution .st-username').empty().append(
                        jQuery(".nlw_phrase", jQuery(data.last_editor_html))
                    );
   
                    $('#update-attribution .st-updatedate').empty().append(
                        jQuery(".nlw_phrase", jQuery(data.last_edit_time_html))
                    );

                    self.setPageContent(data.html);

                    $('table.sort')
                        .each(function() { Socialtext.make_table_sortable(this) });

                    // After upload, refresh the wikitext contents.
                    if ($('#wikiwyg_wikitext_textarea').size()) {
                        $.ajax({
                            url: self.uri(),
                            data: { accept: 'text/x.socialtext-wiki' },
                            cache: false,
                            success: function (text) {
                                $('#wikiwyg_wikitext_textarea').val(text);
                            }
                        });
                    }
                }
            } 
        });
    },

    attachmentUrl: function (attach_id) {
        return '/data/workspaces/' + Socialtext.wiki_id +
               '/attachments/' + Socialtext.page_id + ':' + attach_id
    },

    format_bytes: function(filesize) {
        var n = 0;
        var unit = '';
        if (filesize < 1024) {
            unit = '';
            n = filesize;
        } else if (filesize < 1024*1024) {
            unit = 'K';
            n = filesize/1024;
            if (n < 10)
                n = n.toPrecision(2);
            else
                n = n.toPrecision(3);
        } else {
            unit = 'M';
            n = filesize/(1024*1024);
            if (n < 10) {
                n = n.toPrecision(2);
            } else if ( n < 1000) {
                n = n.toPrecision(3);
            } else {
                n = n.toFixed(0);
            }
        }
        return n + unit;
    }
};

})(jQuery);
