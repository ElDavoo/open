package Socialtext::DevPopup;
# @COPYRIGHT@

use strict;
use warnings;
use base 'Socialtext::Base';
use Class::Field qw(field);
use Module::Pluggable require => 1;

field 'rest';
field 'reports' => [];

sub plugin_objects {
    my $self = shift;
    my @objs;
    foreach my $pkg (sort $self->plugins()) {
        my $p = $pkg->new(popup => $self);
        push @objs, $p;
    }
    return @objs;
}

sub init {
    my $self = shift;
    foreach my $plugin ($self->plugin_objects()) {
        $plugin->init();
    }
}

sub add_popup {
    my ($self, $resultref) = @_;
    my $rest = $self->rest();

    # only add a DevPopup to HTML responses
    my %headers = $rest->header();
    my ($hdr_ctype) = grep /type/i, keys %headers;
    my $ctype = $headers{$hdr_ctype};
    return unless ($ctype && ($ctype =~ m{text/html}));

    # generate the HTML for the DevPopup
    my $body = $self->_generateDevPopup($rest);
    $body = _escape_js($body);

    # generate the CSS for the HEAD, and some custom JS
    my $head = qq|
        <style type="text/css">
            * {
              font-size: 10pt;
              color: #000;
            };
            h1, h2 {
              margin: 0px;
              padding: 4px;
            }
            h1 {
              background-color: #eee;
            }
            h2 {
              font-size: 12pt;
              background-color: #ddd;
            }
            .report {
              margin: 0.2em;
            }
            .report .contents {
            }
            .report .contents table {
              width: 90%;
            }
            .report .contents table th {
              font-weight: bold;
              background-color: #f0f0f0;
            }
            .report .contents tbody th {
              text-align: right;
              padding-right: 5px;
            }
            .report .contents tr * {
              border-bottom: 1px solid #ddd;
              vertical-align: top;
            }
        </style>
    |;
    $head = _escape_js($head);

    my $js = qq|
        function toggle(elemId) {
            var elem = document.getElementById(elemId);
            if (elem.style.display == 'none') {
               elem.style.display = 'inline';
            }
            else {
              elem.style.display = 'none';
            }
        }
    |;
    $js = _escape_js($js);

    my $dev_popup = qq{
<script type="text/javascript">
var devpopup_window = window.open("", "devpopup_window", "height=400,width=600,scrollbars,toolbar,resizable");
devpopup_window.document.write("<html>");
devpopup_window.document.write("<head>");
devpopup_window.document.write("$head");

devpopup_window.document.write("\t<s");
devpopup_window.document.write("cript type=\\"text/javascript\\">$js");
devpopup_window.document.write("\t<");
devpopup_window.document.write("/script>");

devpopup_window.document.write("</head>");
devpopup_window.document.write("<body>$body</body>");
devpopup_window.document.write("</html>");
devpopup_window.document.close()
devpopup_window.focus();
</script>
    };

    # latch the dev-popup into the HTML
    if (${$resultref} =~ m{</body>}i) {
        ${$resultref} =~ s{</body>}{$dev_popup</body>}i;
    }
    else {
        ${$resultref} .= $dev_popup;
    }
}

sub _generateDevPopup {
    my ($self, $rest) = @_;
    my $uri  = $rest->request->uri;

    # ask all of our plugins to create their reports
    foreach my $plugin ($self->plugin_objects()) {
        $plugin->generate_report();
    }

    # then build up the body
    my $body = "<h1>$uri</h1>\n";
    foreach my $rpt (@{$self->reports}) {
        my $title  = $rpt->{title};
        my $report = $rpt->{report};
        my $id     = _title_to_id($title);
        $body .= qq{
<div class="report">
  <h2 onclick="toggle('$id')">$title</h2>
  <div id="$id" class="contents" style="display:none">
    $report
  </div>
</div>
};
    }

    return $body;
}

sub _escape_js {
    my $j = shift;
    $j =~ s/\r//g;
    $j =~ s/\\/\\\\/g;
    $j =~ s/"/\\"/g;
    $j =~ s/\n/\\n" + \n\t"/g;
    return $j;
}

sub _title_to_id {
    my $title = shift;
    $title =~ s/\s+/_/g;
    $title =~ s/\W//g;
    return lc($title);
}

sub add_report {
    my ($self, %args) = @_;
    push @{$self->reports}, \%args;
}


1;
