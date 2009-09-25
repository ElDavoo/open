package Socialtext::Job::Delay::LongLived;
# @COPYRIGHT@
use Moose;
use Socialtext::Log qw(st_log);
use Time::HiRes qw/sleep/;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

override 'is_long_running' => sub { 1 };

sub do_work {
    my $self  = shift;
    my $delay = $self->arg->{'sleep'} || 10;
    st_log->debug("start long-lived job");
    sleep $delay;
    st_log->debug("finish long-lived job");
    $self->completed();
}

__PACKAGE__->meta->make_immutable;
1;
