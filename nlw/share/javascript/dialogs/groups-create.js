(function ($) {

socialtext.dialog.register('groups-create', function(opts) {
    var buttons = {};

    buttons[ loc('groups.next-step') ] = function() {
        var type = dialog.find('input[name=new-group-type]:checked').val(); 
        if ($.isFunction(opts.onChange)) {
            opts.onChange(type);
            dialog.close();
        }
        else {
            document.location='/st/create_group?type=' + type;
        }
    };

    buttons[ loc('do.cancel') ] = function() {
        dialog.close();
    };

    var dialog = socialtext.dialog.createDialog({
        buttons: buttons,
        html: Jemplate.process('groups-create.tt2', {
            permission_set: opts ? opts.permission_set : undefined,
            loc: loc
        }),
        title: opts && opts.permission_set
            ? loc('groups.change-type')
            : loc('groups.create')
    });

    dialog.find('.lookahead input').lookahead({
        clearOnHide: true,
        requireMatch: true,
        filterType: 'solr',
        url: '/data/groups',
        showAll: function(term) {
            window.location = "/?action=search_groups&search_term=" + encodeURIComponent(term) + ' OR ' + encodeURIComponent(term) + '*';
        },
        params: {
            discoverable: 'include'
        },
        getEntryThumbnail: function(group) {
            return '/data/groups/' + group.value + '/small_photo';
        },
        linkText: function (group) {
            return [group.name, group.group_id, group.description];
        },
        onAccept: function(id, item) {
            window.open('/st/group/' + id);
        },
        displayAs: function(item) {
            return item.title;
        },
        onFirstType: function(element) {
            self.doneFirstType = true;
        }
    });

    return false;
});

})(jQuery);
