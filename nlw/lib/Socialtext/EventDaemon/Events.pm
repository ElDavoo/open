package Socialtext::EventDaemon::Events;
# @COPYRIGHT@
use warnings;
use strict;

use Socialtext::SQL qw(sql_execute);
use Socialtext::JSON qw(decode_json);

use namespace::clean;

use constant DEFAULT_LIMIT => 10;

my ($Events, $UserAccounts, $EventCnt);

# Note: This call blocks! Use it sparingly.
sub Reload {
    my $class = shift;

    # Grab events from the database
    my $sth = sql_execute("
        SELECT *
          FROM event
         WHERE action <> 'view'
         ORDER BY at DESC
    ");
    $Events = $sth->fetchall_arrayref({}) || [];
    $_->{context} = decode_json($_->{context}) for @$Events;
    $EventCnt = $sth->rows;

    # Grab user-account relationships from the database
    $sth = sql_execute("
        SELECT user_id, account_id
          FROM user_account
    ");
    my %user_accounts;
    while (my $row = $sth->fetchrow_hashref()) {
        $user_accounts{$row->{user_id}}{$row->{account_id}} = 1;
    }
    $UserAccounts = \%user_accounts;

    warn "Loaded $EventCnt events into memory.\n";
}

sub Get {
    my ($class, %args) = @_;
    my $user_id = $args{user_id};
    my $limit = $args{limit}
        || $EventCnt < DEFAULT_LIMIT ? $EventCnt : DEFAULT_LIMIT;

    my $accounts = $UserAccounts->{$user_id};

    my @filtered;
    for my $e (@$Events) {
        my $viewable;
        if ($e->{event_class} eq 'signal') {
            for my $a (@{$e->{context}{account_ids}}) {
                $viewable = 1 if $accounts->{$a};
            }
        }
        push @filtered, $e if $viewable;
        last if @filtered >= $limit;
    }

    return \@filtered;
}

sub Put {
    my ($class, $event) = @_;
    $event->{context} = decode_json($event->{context});
    unshift @$Events, $event;
    $EventCnt++;
}

__PACKAGE__->Reload();

1;
