var ST = window.ST = window.ST || {};
(function ($) {

ST.RemoveRestoreContent = function (gallery_id, gadget_id, title) {
    this.gallery_id = gallery_id;
    this.gadget_id = gadget_id;
    this.title = title;
}

var proto = ST.RemoveRestoreContent.prototype = new ST.WidgetsLightbox;

proto.showRemoveLightbox = function () {
    var self = this;
    this.show({
        title: loc('widgets.remove-widget'),
        message: this.confirmMsg('remove'),
        callback: function () { self.removeWidget() }
    });
}

proto.showRestoreLightbox = function () {
    var self = this;
    this.show({
        title: loc('widgets.restore-widget'),
        message: this.confirmMsg('restore'),
        callback: function () { self.restoreWidget() }
    });
}

proto.showDeleteLightbox = function () {
    var self = this;
    this.show({
        title: loc('widgets.permanent-remove'),
        message: this.confirmMsg('delete'),
        callback: function () { self.deleteWidget() }
    });
}

proto.confirmMsg = function (action) {
    switch(action) {
        case 'remove':
            return loc('widgets.confirm-remove=widget?', this.title);
        case 'restore':
            return loc('widgets.confirm-restore=widget?', this.title);
        case 'delete':
            return loc('widgets.confirm-delete=widget?', this.title);
    }
}

proto.show = function (options) {
    $.showLightbox({
        html: this.process('remove-content.tt2', {
            title: options.title,
            gadget_id: this.gadget_id,
            message: options.message
        }),
        close: '#remove-content-lightbox .close'
    });

    var self = this;
    $('#remove-content-yes').click(function() {
        if (options.callback) options.callback();
        return false;
    });
};

proto.error = function (action, error, callback) {
    error = error.split(/\n/).shift();
    var message;
    switch (action) {
        case 'restore':
            message = loc('error.restore=widget,message', this.title, error);
            break;
        case 'remove':
            message = loc('error.remove=widget,message', this.title, error);
            break;
        case 'delete':
            message = loc('error.delete=widget,message', this.title, error);
            break;
    }
    get_lightbox('simple', function () {
        errorLightbox(message, callback);
    });
}

proto.success = function (action) {
    switch(action) {
        case 'restore':
            message = loc('widgets.restored=widget', this.title);
            break;
        case 'remove':
        case 'delete':
            message = loc('widgets.removed=widget', this.title);
            break;
    }
    get_lightbox('simple', function () {
        successLightbox(message, function () { location.reload() });
    });
}

proto.postWidget = function (action, section) {
    var self = this;
    $.hideLightbox();

    var url = '/data/gadgets/gallery/' + this.gallery_id + '/' + section;

    $.ajax({
        url: url,
        type: 'POST',
        data: String(this.gadget_id),
        success: function() {
            self.success(action);
        },
        error: function (response) {
            self.error(action, response.responseText);
        }
    });
};

proto.removeWidget = function () {
    this.postWidget('remove', 'hidden');
};

proto.restoreWidget = function () {
    this.postWidget('restore', 'gadgets');
};

proto.deleteWidget = function () {
    var self = this;
    $.hideLightbox();

    var url = '/data/gadgets/gallery/' + this.gallery_id
            + '/hidden/' + this.gadget_id;

    $.ajax({
        url: url,
        type: 'DELETE',
        success: function() {
            self.success('delete');
        },
        error: function (response) {
            self.error('delete', response.responseText);
        }
    });
};

})(jQuery);
