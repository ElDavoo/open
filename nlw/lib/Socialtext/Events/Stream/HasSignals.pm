package Socialtext::Events::Stream::HasSignals;
# @COPYRIGHT@
use Moose::Role;
use Socialtext::Events::Source::Signals;
use Socialtext::Events::Source::SignalPersonal;
use namespace::clean -except => 'meta';

requires 'assemble';
requires '_build_sources';
requires 'account_ids_for_plugin';

has 'signals_account_ids' => (
    is => 'rw', isa => 'ArrayRef[Int]',
    lazy_build => 1,
);

before 'assemble' => sub {
    my $self = shift;
    $self->signals_account_ids; # force builder
    return;
};

sub _build_signals_account_ids { $_[0]->account_ids_for_plugin('signals'); }

around '_build_sources' => sub {
    my $code = shift;
    my $self = shift;
    my $sources = $self->$code() || [];
   
    my $ids = $self->signals_account_ids;
    return $sources unless $ids && @$ids;

    push @$sources, $self->construct_source(
        'Socialtext::Events::Source::Signals',
        account_ids => $ids,
    );

    # TODO: is there a parameter to exclude direct-messages from certain feeds?
    push @$sources, $self->construct_source(
        'Socialtext::Events::Source::SignalPersonal',
        viewer => $self->viewer,
        user => $self->user,
    );

    return $sources;
};

1;

__END__

=head1 NAME

Socialtext::Events::Stream::HasSignals - Stream role to add standard signals
events.

=head1 DESCRIPTION

Adds regular and direct signals to a Stream.  Direct signals are limited to
those sent/received by the C<viewer>.

Since this class is a Stream role, it can be mixed-in to a Stream class at
run-time.

=head1 SYNOPSIS

To construct a Stream of just Signals events:

    my $stream = Socialtext::Events::Stream->new_with_traits(
        traits => ['HasSignals'], # literally
        viewer => $current_user,
        offset => 0,
        limit => 50,
    );

