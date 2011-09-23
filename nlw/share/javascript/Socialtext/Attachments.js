Socialtext.prototype.attachments = (function($) {
    var _newAttachmentList = [];
    var _attachmentList = [];

    return {
        renderAttachments: function() {
            var html = Jemplate.process('page/attachments.tt2', {
                attachments: st.page.attachments
            });
            $('#st-attachment-listing').html(html);

            $('#st-attachment-listing .person.authorized')
                .each(function() { new Avatar(this) });

            // Delete Attachments
            $('#st-attachment-listing .delete_attachment').unbind('click')
                .click(function() {
                    self.showDeleteInterface(this);
                    return false;
                });

            // Extract Archives
            $('#st-attachment-listing .extract_attachment').unbind('click')
                .click(function() {
                    self.extractAttachment($(this).attr('name'));
                    return false;
                });
        },

        refreshAttachments: function (cb) {
            var self = this;
            var url = st.page.uri()
                    + '/attachments?order=alpha_date;accept=application/json';
            $.ajax({
                url: url,
                cache: false,
                dataType: 'json',
                success: function (list) {
                    st.page.attachments = list;
                    st.attachments.renderAttachments();
                    if ($.isFunction(cb)) cb(list);
                }
            });
        },

        extractAttachment: function (attach_id) {
            var self = this;
            $.ajax({
                type: "POST",
                url: location.pathname,
                cache: false,
                data: {
                    action: 'attachments_extract',
                    page_id: Socialtext.page_id,
                    attachment_id: attach_id
                },
                complete: function () {
                    self.refreshAttachments();
                    st.page.refreshPageContent();
                }
            });
        },

        delAttachment: function (url, refresh) {
            $.ajax({
                type: "DELETE",
                url: url,
                async: false
            });
            if (refresh) {
                this.refreshAttachments();
                st.page.refreshPageContent(true);
            }
        },

        showDeleteInterface: function (img) {
            var self = this;
            var href = $(img).prevAll('a[href!=#]').attr('href');
            
            $(Socialtext.attachments).each(function() {
                if ( href == this.uri ) {
                    Socialtext.selected_attachment = this.name;
                }
            });

            $(self.getNewAttachments()).each(function() {
                if ( href == this.uri ) {
                    Socialtext.selected_attachment = this.name;
                }
            });

            self.process('attachment.tt2');

            // We only process the popup once, so we'll only load the
            // selected_attachment that first time. After that, we need to manually
            // replace the value.
            var popup = $('#st-attachment-delete-confirm');
            popup.html(
                popup.html().replace(/'.*'/,
                    "'" + Socialtext.selected_attachment + "'")
            );

            $('#st-attachment-delete').unbind('click').click(function() {
                var loader = $('<img>').attr('src','/static/skin/common/images/ajax-loader.gif');
                var buttons = $('#st-attachment-delete-buttons');
                var content = buttons.html();
                buttons.html(loader);
                self.delAttachment(href, true);
                self.dialog.close();
                buttons.html(content);
            });

            $.showLightbox({
                content:'#st-attachment-delete-confirm',
                close:'#st-attachment-delete-cancel'
            })
        },

        showDuplicateLightbox: function(files, upload_callback) {
            var html = Jemplate.process('duplicate_files', {
                loc: loc,
                files: files
            });
            $.showLightbox({
                title: loc('file.duplicate-files'),
                html: html
            });

            $('#lightbox .warning').each(function(_, warning) {
                var name = $(this).find('input[name=filename]').val();
                var file = $.grep(files, function(f) { return f.name == name })[0];

                $(warning).find('.cancel').click(function() {
                    $(warning).remove();
                    if (!$('#lightbox .warning').size()) $.hideLightbox();
                    return false;
                });

                $(warning).find('.add').click(function() {
                    $(warning).remove();
                    upload_callback(file, 0);
                    if (!$('#lightbox .warning').size()) $.hideLightbox();
                    return false;
                });

                $(warning).find('.replace').click(function() {
                    $(warning).remove();
                    upload_callback(file, 1);
                    if (!$('#lightbox .warning').size()) $.hideLightbox();
                    return false;
                });
            });
        }
    }
})(jQuery);
