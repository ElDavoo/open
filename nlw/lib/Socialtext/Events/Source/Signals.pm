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

__END__

=head1 NAME

Socialtext::Events::Source::Signals - Signal events visible to the viewer's
accounts.

=head1 DESCRIPTION

Provides C<Socialtext::Events::Event::Signal> events.  Only signals sent to an
account are included in this Source.  Direct signals are from the
C<Socialtext::Events::Source::SignalPersonal> source.

The caller is responsible for doing any C<account_id> filtering.

Since each signal has metadata about which accounts it was sent to, this
Source simply uses that for the visibility calculation.

If C<activity_mode> is enabled, only signals sent by the "owner" (C<user>
attribute) or that mention the owner are displayed.

=head1 SYNOPSIS

Use C<construct_source> from a Stream where possible, but you could also
construct this stream directly.

    my $src = Socialtext::Events::Source::Signals->new(
        activity_mode => 1, # for the ProfileActivity Stream component
        account_ids => [...],
        viewer => $current_user,
        filter => ...,
        ...
    );

=head1 TODO

Use the same visibility criteria as in C<Socialtext::Signal>.
