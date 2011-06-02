/* HTML5 file upload */
if (!XMLHttpRequest.prototype.sendAsBinary) {
    // For chrome
    XMLHttpRequest.prototype.sendAsBinary = function(datastr) {
        function byteValue(x) {
            return x.charCodeAt(0) & 0xff;
        }
        var ords = Array.prototype.map.call(datastr, byteValue);
        var ui8a = new Uint8Array(ords);
        this.send(ui8a.buffer);
    }
}
$(function() {
    var $dropbox = $('#dropbox');
    if (!$dropbox.size()) return; // Early out on non-page urls

    $('#mainWrap').get(0).addEventListener("dragenter", function (evt) {
        $dropbox.show();
    }, false);
    $('#mainWrap').get(0).addEventListener("dragover", function (evt) {
        $dropbox.show();
    }, false);
    $('#mainWrap').get(0).addEventListener("dragexit", function (evt) {
        $dropbox.hide();
    }, false);

    $dropbox.get(0).addEventListener("dragenter", function (evt) {
        evt.stopPropagation();
        evt.preventDefault();
        $dropbox.show().addClass('over');
    }, false);
    $dropbox.get(0).addEventListener("dragexit", function (evt) {
        evt.stopPropagation();
        evt.preventDefault();
        $dropbox.hide().removeClass('over');
    }, false);
    $dropbox.get(0).addEventListener("dragover", function (evt) {
        evt.stopPropagation();
        evt.preventDefault();
    }, false);
    $dropbox.get(0).addEventListener('drop', function(evt) {
        evt.stopPropagation();
        evt.preventDefault();

        // Hide the dropbox
        $dropbox.hide().removeClass('over');

        /* Actual File upload */
        $.each(evt.dataTransfer.files, function(_, file) {
            var $progress = $('<div class="dropbox-progress"></div>');
            $progress.insertAfter('#dropbox');
            $progress.progressbar({ value: 0 });

            var reader = new FileReader();  // reader
            var xhr = new XMLHttpRequest(); // writer

            xhr.upload.addEventListener("progress", function(e) {
                var percentage = 0;
                if (e.lengthComputable) {
                    percentage = Math.round((e.loaded / e.total) * 100);
                }
                $progress.progressbar({ value: percentage });
            }, false);

            var url = '/data/workspaces/' + Socialtext.wiki_id
                    + '/pages/' + Socialtext.page_id 
                    + '/attachments?name=' + encodeURIComponent(file.name);

            xhr.open('POST', url, true);
            xhr.setRequestHeader("Content-Type", file.type);
            reader.onload = function(evt) {
                xhr.sendAsBinary(evt.target.result);
            };
            xhr.onreadystatechange = function() {
                if (xhr.readyState == 4) {
                    get_lightbox('attachment', function () {
                        $progress.remove()
                        Attachments.refreshAttachments();
                    });
                }
            };
            reader.onloadend = function(evt) {
                $progress.progressbar({ value: 100 });
            };
            reader.readAsBinaryString(file);
        });
    }, false);
});
