package Socialtext::DevPopup::Plugin::HTTPHeaders;
# @COPYRIGHT@

use strict;
use warnings;
use base 'Socialtext::Base';
use Class::Field qw(field);

field 'popup';

sub init { }

sub generate_report {
    my $self  = shift;
    $self->_env_vars_report();
    $self->_incoming_hdrs_report();
    $self->_outgoing_hdrs_report();
}

sub _env_vars_report {
    my $self = shift;

    my $body =
        join $/,
        map { qq{<tr><th>$_</th><td>$ENV{$_}</td></tr>} }
        sort keys %ENV;

    my $report = qq{
        <table>
          <tbody>$body</tbody>
        </table>
    };

    $self->popup->add_report(
        title   => 'Environment Variables',
        report  => $report,
    );
}

sub _incoming_hdrs_report {
    my $self  = shift;
    my $query = $self->popup->rest->query;

    # HTTP headers
    if ($query->http) {
        my $body =
            join $/,
            map { qq{<tr><th>$_</th><td>@{[$query->http($_)]}</td></tr>} }
            sort $query->http;
        my $report = qq{
            <table>
              <tbody>$body</tbody>
            </table>
        };
        $self->popup->add_report(
            title   => 'Incoming HTTP Headers',
            report  => $report,
        );
    }

    # HTTPs headers
    if ($query->https) {
        my $body =
            join $/,
            map { qq{<tr><th>$_</th><td>@{[$query->https($_)]}</td></tr>} }
            sort $query->https;
        my $report = qq{
            <table>
              <tbody>$body</tbody>
            </table>
        };
        $self->popup->add_report(
            title   => 'Incoming HTTPS Headers',
            report  => $report,
        );
    }
}

sub _outgoing_hdrs_report {
    my $self     = shift;
    my %headers  = $self->popup->rest->header;
    my $body =
        join $/,
        map { qq{<tr><th>$_</th><td>$headers{$_}</td></tr>} }
        sort keys %headers;
    my $report = qq{
        <table>
          <tbody>$body</tbody>
        </table>
    };
    $self->popup->add_report(
        title   => 'Outgoing HTTP Headers',
        report  => $report,
    );
}

1;
