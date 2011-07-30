(function($) {

if (typeof(Activities) == 'undefined') Activities = {};

Activities.NetworkDropdown = function(opts) {
    this.extend(opts);
    this.requires([
        'user', 'account_id'
    ]);
}

Activities.NetworkDropdown.prototype = new Activities.Base()

$.extend(Activities.NetworkDropdown.prototype, {
    toString: function() { return 'Activities.NetworkDropdown' },

    _defaults: {
        node: $('body')
    }, 

    show: function(callback) {
        var self = this;
        $.getJSON("/data/users/" + self.user, function(data) {
            self.appdata = new Activities.AppData({
                workspace_id: self.workspace_id,
                prefix: self.prefix,
                instance_id: 1,
                user_data: data,
                node: true,
                owner: true,
                viewer: true,
                owner_id: true
            });

            var default_network = 'account-' + self.account_id;
            self.findId('st-edit-summary-signal-to').val(default_network);

            self.appdata.selectSignalToNetwork = function(network){
                self.findId('st-edit-summary-signal-to').val(network);
            };

            self.findId('signal_network').text('').dropdown({
                selected: default_network,
                fixed: null,
                width: self.width || '170px',
                options: self.appdata.signalNetworks(),
                onChange: function(option) {
                    if (option.warn) {
                        self.findId('signal_network_warning').fadeIn('fast');
                    }
                    else {
                        self.findId('signal_network_warning').fadeOut('fast');
                    }
                    self.appdata.selectSignalToNetwork(option.value);
                    self.findId('st-edit-summary-signal-checkbox')
                        .attr('checked', true);
                }
            });

            self.findId('signal_network').children('a').css({ 
                width: ( 
                    self.width || ( 
                        ($.browser.msie && $.browser.version < 7) 
                            ? '85px' // IE6 
                            : '105px' 
                    ) 
                ), 
                verticalAlign: 'top', 
                height: '30px', 
                overflow: 'hidden', 
                display: 'inline-block', 
                whiteSpace: 'nowrap' 
            }); 

            if ($.browser.msie) {
                if (self.width) {
                    self.findId('signal_network').children('a').css({
                        height: '16px',
                        marginTop: '7px'
                    });
                }
                else {
                    self.findId('signal_network').children('a').css({
                        marginLeft: '-4px',
                        marginTop: '-9px'
                    });
                }
            }
            else if (self.width) {
                self.findId('signal_network').children('a').css({
                    marginTop: '2px'
                });
            }

            self.findId('signal_network').find('.dropdownOptions').css({
                'margin-top': '-15px',
                'margin-left': '11em'
            });
            self.findId('signal_network').find('.dropdownOptions li').css({
                'line-height': '16px'
            });

            self.appdata.setupSelectSignalToNetworkWarningSigns();
        });
    }
});

})(jQuery);
