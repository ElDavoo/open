package Socialtext::Job::Upgrade::Monitor;
# @COPYRIGHT@
use Moose::Role;
use Socialtext::JobCreator;
use Socialtext::Log qw/st_log/;
use Clone qw/clone/;
use Socialtext::Timer qw/time_scope/;
use namespace::clean -except => 'meta';

requires qw/Monitor_job_types finish_work Job_delay/;

sub do_work {
    my $self = shift;
    my $t = time_scope('monitor_do_work');

    (my $name = ref($self)) =~ s/^.+:://g;

    # find the count of remaining jobs we're monitoring.
    my $jobs = Socialtext::Jobs->new;
    my $count = 0;
    for my $type ($self->Monitor_job_types) {
        $count += $jobs->job_count("Socialtext::Job::$type");
    }
    if ($count) {
        st_log->info(
            "$name UPGRADE: There are $count monitored jobs remaining.");

        my @clone_args = map { $_ => $self->job->$_ }
            qw(funcid funcname priority uniqkey coalesce);
        my $next_job = TheSchwartz::Moosified::Job->new({
            @clone_args,
            run_after => time + $self->Job_delay,
            arg => {
                %{clone($self->arg)},
                last_count => $count,
            }
        });
        $self->replace_with($next_job);
    }
    else {
        st_log->info("$name UPGRADE: ".
            "There are no more monitored jobs. ".
            "Finishing work.");
        Finish_work: {
            my $t2 = time_scope('monitor_finish');
            $self->finish_work();
        }
        $self->completed();
    }
}

1;
