
var sametime_helper = {

    STATUS_AVAILABLE : 1, 
    STATUS_AVAILABLE_MOBILE : 6, 
    STATUS_AWAY : 2, 
    STATUS_AWAY_MOBILE : 7, 
    STATUS_DND : 3, 
    STATUS_DND_MOBILE : 8, 
    STATUS_IN_MEETING : 5, 
    STATUS_IN_MEETING_MOBILE : 10, 
    STATUS_NOT_USING : 4, 
    STATUS_OFFLINE : 0, 
    STATUS_UNKNOWN : -1, 

    getStatusImgUrl: function(personStatus) { 
        var url = "http://localhost:59449/stwebapi/images/"; 
  
        switch(personStatus){ 
            case sametime_helper.STATUS_AVAILABLE: 
            return url + "ST_Awns_Active.png"; 

            case sametime_helper.STATUS_AVAILABLE_MOBILE: 
            return url + "ST_Awns_Active_Mobile.png"; 

            case sametime_helper.STATUS_AWAY: 
            return url + "ST_Awns_Away.png"; 

            case sametime_helper.STATUS_AWAY_MOBILE: 
            return url + "ST_Awns_Away_Mobile.png"; 

            case sametime_helper.STATUS_DND: 
            return url + "ST_Awns_DND.png"; 

            case sametime_helper.STATUS_DND_MOBILE: 
            return url + "ST_Awns_DND_Mobile.png"; 

            case sametime_helper.STATUS_IN_MEETING: 
            return url + "ST_Awns_InAMtng.png"; 

            case sametime_helper.STATUS_IN_MEETING_MOBILE: 
            return url + "ST_Awns_InAMtg_Mobile.png"; 

            default: 
            return url + "ST_Awns_Offline.png"; 
        } 
    }
};

var ocs_helper = {
    statuses: {
        0: [loc('Online'), 'ocs-green.png'], 
        1: [loc('Offline'), 'ocs-gray.png'],
        2: [loc('Away'), 'ocs-red.png'], 
        3: [loc('Busy'), 'ocs-orange.png'],
        4: [loc('Be right back'), 'ocs-gold.png'], 
        5: [loc('On the phone'), 'ocs-gold.png'],
        6: [loc('Lunch'), 'ocs-gold.png'],
        7: [loc('Meeting'), 'ocs-gold.png'],
        8: [loc('Out of office'), 'ocs-gold.png'],
        9: [loc('Do not disturb'), 'ocs-donotenter.png'],
        15: [loc('Do not disturb but allowed'), 'ocs-donotenter.png'],
        16: [loc('Idle online'), 'ocs-turquoise.png']
    },

    create_ocs_field: function($span, username) {
        if (! $.browser.msie) {
            $span.text(username+" "+loc('(requires Internet Explorer)'));
        } 
        else {
            $span.text(username); 
            var namectrl;
            try {
                namectrl = new ActiveXObject('Name.NameCtrl.1');
                $span.wrap($('<a></a>').click(
                    function(e) {
                        namectrl.ShowOOUI(username, 0, 100,100);
                        e.preventDefault();
                    }));
                if (namectrl.PresenceEnabled) {
                    namectrl.GetStatus(username, "empty");
                    var $statusspan = $('<span></span>');
                    $span.append($statusspan);
                    namectrl.OnStatusChange = function(name, status, id) {
                        var statusarray=ocs_helper.statuses[status];
                        if (statusarray) {
                            $statusspan.empty().append($("<img></img>").
                            attr('src', '/static/skin/s3/images/'+statusarray[1]).
                            attr('title', statusarray[0]));
                        }
                    }
                };
            } 
            catch(e) {
                // No namectrl ActiveX
            }
        }
    }
};
