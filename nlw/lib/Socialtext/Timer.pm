package Socialtext::Timer;
# @COPYRIGHT@
use strict;
use warnings;

use Time::HiRes qw( time );
use Carp qw/croak/;
use Guard ();

use base qw/Exporter/;
our $VERSION = 1.0;
our @EXPORT = ();
our @EXPORT_OK = qw(&time_this &time_scope);

our $Timings = {};

sub Reset {
    my $class = shift;
    $Timings = {};
    $class->Start('overall');
}

sub Report {
    my $class = shift;
    foreach my $timer (keys(%$Timings)) {
        if (ref($Timings->{$timer}->{timer})) {
            $class->Stop($timer);
        }
    }
    return {map {$_ => sprintf('%0.03f', $Timings->{$_}->{timer})} keys(%$Timings)}
}

sub ExtendedReport {
    my $class = shift;
    foreach my $timer (keys(%$Timings)) {
        if (ref($Timings->{$timer}->{timer})) {
            $class->Stop($timer);
        }
    }

    my %report;
    foreach my $key (keys %{$Timings}) {
        my $duration = $Timings->{$key}->{timer};
        my $count    = $Timings->{$key}->{how_many} || 1;
        my $average  = $duration / $count;
        $report{$key} = {
            duration => sprintf('%0.03f', $duration),
            count    => $count,
            average  => sprintf('%0.03f', $average),
        };
    }
    return \%report;
}

sub Add {
    my $class = shift;
    my $timed = shift;
    my $how_long = shift;
    $Timings->{$timed}->{how_many}++;
    $Timings->{$timed}->{timer} ||= 0;
    $Timings->{$timed}->{timer} += $how_long;
}

sub Start {
    my $class = shift;
    my $timed = shift;
    local $@;
    $Timings->{$timed}->{how_many}++;
    $Timings->{$timed}->{counter}++;
    $Timings->{$timed}->{timer} = $class->new();
}

sub Pause {
    my $class = shift;
    my $timed = shift;
    local $@;

    if (ref($Timings->{$timed}->{timer})) {
        $Timings->{$timed}->{counter}--;
        if ($Timings->{$timed}->{counter} < 1) {
            $class->Stop($timed);
        }
    }
}

sub Continue {
    my $class = shift;
    my $timed = shift;
    local $@;
    if (ref($Timings->{$timed}->{timer})) {
        $class->Stop($timed);
    }
    $Timings->{$timed}->{how_many}++;
    $Timings->{$timed}->{counter}++;
    $Timings->{$timed}->{timer} = $class->new($Timings->{$timed}->{timer});
}

sub Stop {
    my $class = shift;
    my $timed = shift;
    local $@;
    $Timings->{$timed}->{timer} = $Timings->{$timed}->{timer}->elapsed()
        if ref($Timings->{$timed}->{timer});
}

sub new {
    my $class = shift;
    my $start_offset = shift || 0;
    my $self = {};
    bless $self, $class;
    $self->start_timing($start_offset);
    return $self;
}

sub start_timing {
    my $self = shift;
    my $offset = shift;
    $self->{_start_time} = time() - $offset;
}

sub elapsed {
    my $self = shift;
    return time() - $self->{_start_time};
}

sub time_this(&$) {
    __PACKAGE__->Continue($_[1]);
    eval { $_[0]->() };
    __PACKAGE__->Pause($_[1]);
    croak $@ if $@;
}

sub time_scope($) {
    my $name = shift;
    __PACKAGE__->Continue($name);
    return Guard::guard { __PACKAGE__->Pause($name) };
}

1;
