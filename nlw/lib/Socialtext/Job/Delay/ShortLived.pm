package Socialtext::Job::Delay::ShortLived;
# @COPYRIGHT@
use Moose;
use Socialtext::Log qw(st_log);
use Time::HiRes qw/sleep/;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

override 'is_long_running' => sub { 0 };

sub do_work {
    my $self  = shift;
    my $delay = $self->arg->{'sleep'} || 0.2;
    st_log->debug("start short-lived job");
    sleep $delay;
    st_log->debug("finish short-lived job");
    $self->completed();
}

__PACKAGE__->meta->make_immutable;
1;
