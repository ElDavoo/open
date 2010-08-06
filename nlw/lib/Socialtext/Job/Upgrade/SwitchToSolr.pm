package Socialtext::Job::Upgrade::SwitchToSolr;
# @COPYRIGHT@
use Moose;
use Socialtext::JobCreator;
use Socialtext::Log qw/st_log/;
use Clone qw/clone/;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

my $Job_delay = 15 * 60;
override 'retry_delay' => sub { $Job_delay };
override 'max_retries' => sub {0x7fffffff};

sub do_work {
    my $self = shift;

    # find the count of PageReIndex and AttachmentReIndex jobs
    my $jobs = Socialtext::Jobs->new;
    my $count = 0;
    for qw(Page Attachment) {
        $count += $jobs->job_count("Socialtext::Job::${_}ReIndex");
    }
    if ($count) {
        st_log->info("There are $count re-index jobs remaining.");
        my @clone_args = map { $_ => $self->job->$_ }
            qw(funcid funcname priority uniqkey coalesce);
        my $next_job = TheSchwartz::Moosified::Job->new({
            @clone_args,
            run_after => time + $Job_delay,
            arg => {
                clone($self->arg),
                last_count => $count,
            }
        });
        $self->replace_with($next_job);
    }
    else {
        st_log->info("There are no more re-index jobs. Enabling Solr for "
            "workspace search now.");
        $self->_enable_solr();
        $self->completed();
    }
}

sub _enable_solr {
    my $self = shift;
}

__PACKAGE__->meta->make_immutable;
1;
=head1 NAME

Socialtext::Job::Upgrade::SwitchToSolr - When the time is right, make Solr the
                                         default for workspace search.

=head1 SYNOPSIS

  use Socialtext::JobCreator;

    Socialtext::JobCreator->insert(
        'Socialtext::Job::Upgrade::SwitchToSolr'
    );

=head1 DESCRIPTION

Looks for outstanding *ReIndex jobs and when they are done
it switches workspace search over to Solr.

=cut
