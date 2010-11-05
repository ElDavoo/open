package Socialtext::Job::Upgrade::MakeExplorePublic;
# @COPYRIGHT@
use Moose;
use Socialtext::Log qw/st_log/;
use Socialtext::System qw/shell_run/;
use Socialtext::Helpers;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';
with 'Socialtext::Job::Upgrade::Monitor';

sub Monitor_job_types {qw/SignalReIndex Upgrade::ReindexSignals/}
sub Job_delay {15 * 60} # 15 mins.

override 'retry_delay' => \&Job_delay;
override 'max_retries' => sub {0x7fffffff};

sub finish_work {
    my $self = shift;

    shell_run('sudo st-appliance-set-config explore_is_public 1');

    # The 'Explore' link appears in the main nav section, which is cached for
    # perf reasons. Wipe out the cache.
    Socialtext::Helpers::clean_user_frame_cache();

    st_log->info('Explore has been made public.');
}

__PACKAGE__->meta->make_immutable;
1;
