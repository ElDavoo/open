package Socialtext::Events::Source::SignalPersonal;
# @COPYRIGHT@
use Moose;
use MooseX::StrictConstructor;
use Socialtext::SQL::Builder qw/sql_abstract/;
use Socialtext::Events::Event::Signal;
use namespace::clean -except => 'meta';

with 'Socialtext::Events::Source', 'Socialtext::Events::Source::FromDB';

use constant event_type => 'Socialtext::Events::Event::Signal';
use constant query_name => 'signal_personal';

sub query_and_binds {
    my $self = shift;

    my @where = (
        event_class => 'signal',
        \"is_direct_signal(actor_id,person_id)",
    );

    if ($self->viewer_id == $self->user_id) {
        push @where, -or => [
            actor_id => $self->viewer_id,
            person_id => $self->viewer_id,
        ];
    }
    else {
        # direct between the viewer and the user
        push @where, -or => [
            {
                actor_id => $self->viewer_id,
                person_id => $self->user_id,
            },
            {
                actor_id => $self->user_id,
                person_id => $self->viewer_id,
            },
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

Socialtext::Events::Source::SignalPersonal - Direct-Signal events occuring
between two users.

=head1 DESCRIPTION

Provides C<Socialtext::Events::Event::Signal> events that are "direct" signals.

If just a C<viewer> is supplied, then they are the sender or recipient.

If a C<user> ("owner") is also supplied, then the signal is direct between the
viewer and user.

=head1 SYNOPSIS

Use C<construct_source> from a Stream where possible, but you could also
construct this stream directly.

    my $src = Socialtext::Events::Source::Signals->new(
        viewer => $current_user,
        viewer => $profile_owner,
        filter => ...,
        ...
    );

