(function ($) {

function errorString(data, new_title) {
    if (data.page_exists) {
        var button = 'WHAAT';
        return loc('error.page-exists=title,button', new_title, button);
    }
    else if (data.page_title_bad) {
        return loc('error.invalid-page-name=title', new_title);
    }
    else if (data.page_title_too_long) {
        return loc('error.long-page-name=title', new_title);
    }
    else if (data.same_title) {
        return loc('error.same-page-name=title', new_title);
    }
}

st.dialog.register('page-duplicate', function(opts) {
    var dialog = st.dialog.createDialog({
        html: st.dialog.process('page-duplicate.tt2', st),
        title: loc('page.duplicate=title', st.page.title),
        buttons: [
            {
                id: 'st-duplicate-savelink',
                text: loc('do.duplicate'),
                click: function() { dialog.find('form').submit() }
            },
            {
                id: 'st-duplicate-cancellink',
                text: loc('do.cancel'),
                click: function() { dialog.close() }
            }
        ]
    });
    $("#st-duplicate-newname").val(
        loc('page.duplicate=title', st.page.title)
    );
    $("#st-duplicate-newname").select().focus();

    dialog.find('form').submit(function () {
        dialog.disable();
        $.ajax({
            url: st.page.web_uri(),
            data: $(this).serializeArray(),
            type: 'post',
            dataType: 'json',
            async: false,
            success: function (data) {
                var title = dialog.find('input[name=new_title]').val();
                var error = errorString(data, title);
                if (error) {
                    dialog.find('form').append(
                        $('<input name="clobber" type="hidden">')
                            .attr('value', title)
                    );
                    dialog.find('.error').html(error).show();
                    dialog.enable();
                }
                else {
                    dialog.close();
                    document.location = '/' + st.workspace.name + '/' + title;
                }
            },
            error: function (xhr, textStatus, errorThrown) {
                dialog.find('.error').html(textStatus).show();
                dialog.enable();
            }
        });

        return false;
    });
});

})(jQuery);
