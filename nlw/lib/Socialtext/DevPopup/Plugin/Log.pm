package Socialtext::DevPopup::Plugin::Log;
# @COPYRIGHT@

use strict;
use warnings;
use base 'Socialtext::Base';
use Class::Field qw(field);
use Socialtext::Log qw(st_log);
use Log::Dispatch::File;

field 'popup';

our @LOG_HISTORY;   # class-wide var to hold history

sub init {
    my $self = shift;

    # add a new Log::Dispatch handler to ST::Log which will gather up all of
    # the log entries for us
    my %options = (
        name        => 'DevPopup',
        min_level   => 'debug',
        filename    => File::Spec->devnull(),
        callbacks   => sub {
            my %args = @_;
            push @LOG_HISTORY, [$args{level}, $args{message}];
        },
    );

    undef @LOG_HISTORY;
    st_log->log->add( Log::Dispatch::File->new(%options) );
}

sub generate_report {
    my $self = shift;

    my $report = 'No entries logged via <code>st_log</code>';
    if (@LOG_HISTORY) {
        my $body =
            join $/,
            map { qq{<tr><td>$_->[0]</td><td>$_->[1]</td></tr>} }
            @LOG_HISTORY;

        $report = qq{
            <table>
              <thead><tr><th>Level</th><th>Message</th></tr></thead>
              <tbody>$body</tbody>
            </table>
        };
    }

    $self->popup->add_report(
        title   => 'Log Entries',
        report  => $report,
    );
}

1;
