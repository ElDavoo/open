function load_reports ()
{
    var divs = jQuery(".report");
    for (var i=0; i<divs.length; i++) {
        var div = jQuery(divs[i]);
        var id = div.attr('report');
        var user = div.attr('username');
        user = user ? ';username=' + user : '';
        var action = div.attr('action');
        action = action ? ';action=' + action : '';
        var workspace = div.attr('workspace');
        workspace = workspace ? ';workspace=' + workspace : '';
        var start_time = jQuery("#start_date").val();
        var duration   = jQuery("#duration").val();

        if (start_time == 'YYYY-MM-DD') {
            start_time = 'now';
        }

        var short_url = id + "/" + start_time + "/" + duration + ".html";
        var report_url = "/nlw/reports/" + short_url + "?"
            + user
            + workspace
            + action;
        var csv_url = report_url.replace('.html', '.csv');

        var url_div = div.children(".report_url");
        url_div.html(
            '<a href="' + report_url + '">' + short_url + '</a>'
            + ' (<a href="' + csv_url + '">CSV</a>)'
        );

        var report_div = div.children(".report_output");
        report_div.html('Loading ...');
        report_div.load(report_url + ';top=10');
    }
}

jQuery(load_reports);
