(function($){

socialtext.dialog.register('attachments-delete', function(opts) {
    var dialog = socialtext.dialog.createDialog({
        html: socialtext.dialog.process('attachments-delete.tt2', opts),
        title: loc('file.delete'),
        buttons: [
            {
                text: loc('do.delete'),
                id: "st-attachment-delete",
                click: function() {
                    st.attachments.delAttachment(opts.href, true);
                    dialog.close();
                }
            },
            {
                text: loc('do.close'),
                id: 'st-attachments-delete-cancel',
                click: function() { dialog.close() }
            }
        ],
    });
});

})(jQuery);
