package Socialtext::Events::Source::Signals;
# @COPYRIGHT@
use Moose;
use MooseX::StrictConstructor;
use Socialtext::SQL::Builder qw/sql_abstract/;
use Socialtext::Events::Event::Signal;
use namespace::clean -except => 'meta';

with 'Socialtext::Events::Source', 'Socialtext::Events::Source::FromDB';

has 'account_ids' => ( is => 'ro', isa => 'ArrayRef[Int]', required => 1 );
has 'activity_mode' => ( is => 'ro', isa => 'Bool', default => undef );

use constant event_type => 'Socialtext::Events::Event::Signal';

sub query_and_binds {
    my $self = shift;

    my ($acct_sql, @acct_binds) = sql_abstract()->select(
        'signal_account', 'signal_id', [
            account_id => {-in => $self->account_ids},
        ], 
    );

    my @where = (
        event_class => 'signal',
        \"NOT is_direct_signal(actor_id,person_id)",
        \["signal_id IN ($acct_sql)", @acct_binds]
    );

    if ($self->activity_mode) {
        my $mentioned = \[
            q{EXISTS (
                SELECT 1
                  FROM topic_signal_user tsu
                 WHERE tsu.signal_id = event.signal_id
                   AND tsu.user_id = ?
            )}, $self->user_id
        ];
        push @where, -or => [
            actor_id => $self->user_id,
            $mentioned
        ];
    }

    push @where, -nest => $self->filter->generate_filter(
        qw(before after actor_id person_id)
    );

    my $sa = sql_abstract();
    my ($sql, @binds) = $sa->select(
        'event', $self->columns, \@where, 'at DESC', $self->limit
    );
    return $sql, \@binds;
}

around 'columns' => sub {
    return shift->().', person_id, signal_id';
};

__PACKAGE__->meta->make_immutable;
1;
