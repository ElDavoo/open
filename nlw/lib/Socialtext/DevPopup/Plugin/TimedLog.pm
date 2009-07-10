package Socialtext::DevPopup::Plugin::TimedLog;
# @COPYRIGHT@

use strict;
use warnings;
use base 'Socialtext::Base';
use Class::Field qw(field);
use Socialtext::Timer;

field 'popup';

sub init { };

sub generate_report {
    my $self = shift;
    my $data = Socialtext::Timer->Report();

    my $body =
        join $/,
        map { qq{<tr><td>$_</td><td>$data->{$_}</td></tr>} }
        reverse sort { $data->{$a} <=> $data->{$b} }
        keys %{$data};

    my $report = qq{
        <table>
          <thead><tr><th>Timer</th><th>Time Taken (secs)</th></tr></thead>
          <tbody>$body</tbody>
        </table>
    };

    $self->popup->add_report(
        title   => 'Timed Log',
        report  => $report,
    );
}

1;
