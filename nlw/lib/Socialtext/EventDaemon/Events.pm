package Socialtext::EventDaemon::Events;
# @COPYRIGHT@
use warnings;
use strict;

use Socialtext::SQL qw(sql_execute);

use namespace::clean;

use constant DEFAULT_LIMIT => 10;

my ($Events, $EventCnt);

# Note: This call blocks! Use it sparingly.
sub Reload {
    my $class = shift;
    my $sth = sql_execute("
        SELECT *
          FROM event
         WHERE action <> 'view'
         ORDER BY at DESC
    ");
    $Events = $sth->fetchall_arrayref({}) || [];
    $EventCnt = $sth->rows;
    warn "Loaded $EventCnt events into memory.\n";
}

sub Get {
    my ($class, %args) = @_;
    my $limit = $args{limit}
        || $EventCnt < DEFAULT_LIMIT ? $EventCnt : DEFAULT_LIMIT;
    return $EventCnt ? [ @$Events[0 .. $limit] ] : [];
}

sub Put {
    my ($class, $event) = @_;
    unshift @$Events, $event;
    $EventCnt++;
}

__PACKAGE__->Reload();

1;
