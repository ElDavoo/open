
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
