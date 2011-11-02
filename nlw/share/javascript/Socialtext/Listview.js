Socialtext.prototype.setupListview = (function($){
    return function(query_start) {
        $('#sort-picker').dropdown().live('change', function() {
            var selected = jQuery('select#sort-picker').val();
            window.location = query_start + ';' + selected;
        });

        $('#st-listview-submit-pdfexport').live('click', function() {
            if (!$('.st-listview-selectpage-checkbox:checked').size()) {
                alert(loc("error.no-page-pdf"));
            }
            else {
                $('#st-listview-action').val('pdf_export')
                $('#st-listview-filename').val(Socialtext.wiki_id + '.pdf');
                $('#st-listview-form').submit();
            }
            return false;
        });

        $('#st-listview-submit-rtfexport').live('click', function() {
            if (!$('.st-listview-selectpage-checkbox:checked').size()) {
                alert(loc("error.no-page-doc"));
            }
            else {
                $('#st-listview-action').val('rtf_export')
                $('#st-listview-filename').val(Socialtext.wiki_id + '.rtf');
                $('#st-listview-form').submit();
            }
            return false;
        });

        $('#st-listview-selectall').live('click', function () {
            var self = this;
            $('input[type=checkbox]').each(function() {
                if ( ! $(this).attr('disabled') ) {
                    $(this).attr('checked', self.checked);
                }
            });
            return true;
        });

        $('td.listview-watchlist a[id^=st-watchlist-indicator-]').each(function(){
            $(this).click(
                st.makeWatchHandler(
                    $(this).attr('id').replace(/^st-watchlist-indicator-/, '')
                )
            );
        });

    };
})(jQuery);
