#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::Socialtext tests => 62;
use Test::Exception;

fixtures('foobar');

BEGIN {
    use_ok 'Socialtext::Jobs';
    use_ok 'Socialtext::JobCreator';
}

sub clear_and_run (&);

my $hub = new_hub('foobar', 'system-user');
ok $hub, "loaded hub";
my $foobar = $hub->current_workspace;
ok $foobar, "loaded foobar workspace";

my $jobs = Socialtext::Jobs->instance;
lives_ok {
     $jobs->clear_jobs();
} "can clear jobs";

Load_jobs: {
    my @job_types = $jobs->job_types;
    my @test_jobs = grep { $_ eq 'Socialtext::Job::Test' } @job_types;
    ok @test_jobs == 1, "Test job available";
    ok !$INC{"Socialtext/Job/Test.pm"}, 'test module is *not* loaded';
    use_ok 'Socialtext::Job::Test';
    ok $INC{"Socialtext/Job/Test.pm"}, 'test module now loaded';
}

Queue_job: clear_and_run {
    my @jobs = Socialtext::Jobs->list_jobs(
        funcname => 'Socialtext::Job::Test',
    );
    is scalar(@jobs), 0, 'no jobs to start with';

    my @job_args = ('Socialtext::Job::Test' => {test => 1} );
    dies_ok {
        $jobs->insert(@job_args);
    } "can't create jobs directly";

    my $jh;
    lives_ok {
        $jh = Socialtext::JobCreator->insert(@job_args);
    } "used the job creator interface";
    ok $jh;

    @jobs = $jobs->list_jobs({
        funcname => 'Socialtext::Job::Test',
    });
    is scalar(@jobs), 1, 'found a job';
    my $j = shift @jobs;
    is $j->funcname, 'Socialtext::Job::Test', 'funcname is correct';
};

Process_a_job: clear_and_run {
    Socialtext::JobCreator->insert('Socialtext::Job::Test', test => 1);
    is scalar($jobs->list_jobs( funcname => 'Socialtext::Job::Test' )), 1;
    is $Socialtext::Job::Test::Work_count, 0;

    $jobs->can_do('Socialtext::Job::Test');
    $jobs->work_once();

    is scalar($jobs->list_jobs( funcname => 'Socialtext::Job::Test' )), 0;
    is $Socialtext::Job::Test::Work_count, 1;
};

Process_a_failing_job: clear_and_run {
    local $Socialtext::Job::Test::Retries = 1;

    Socialtext::JobCreator->insert('Socialtext::Job::Test', fail => 1);
    is scalar($jobs->list_jobs( funcname => 'Socialtext::Job::Test' )), 1;
    is $Socialtext::Job::Test::Work_count, 0;
   
    $jobs->can_do('Socialtext::Job::Test');
    $jobs->work_once();

    my @jobs = $jobs->list_jobs( funcname => 'Socialtext::Job::Test', want_handle => 1 );
    is scalar(@jobs), 1;
    my @failures = $jobs[0]->failure_log;
    is scalar(@failures), 1;
    like $failures[0], qr/^failed!\n/;
    is $Socialtext::Job::Test::Work_count, 0;
};

Process_a_failing_cmd_job: clear_and_run {
    use_ok 'Socialtext::Job::Cmd';

    my $handle = Socialtext::JobCreator->insert('Socialtext::Job::Cmd', cmd => '/bin/false');;
    is scalar($jobs->list_jobs( funcname => 'Socialtext::Job::Cmd' )), 1;
   
    $jobs->can_do('Socialtext::Job::Cmd');
    $jobs->work_once();

    my @failures = $handle->failure_log;
    is scalar(@failures), 1;
    is $failures[0], "rc=256";
    is $handle->exit_status, 256, 'correct exit status';
};

Blah_does_not_exist: clear_and_run {
    my @tests = (
        { desc => 'workspace does not exist',
            args => {
                workspace_id => -2,
                get_workspace => 1,
            },
            matcher => qr/workspace id=-2 no longer exists/i,
        },
        { desc => 'page does not exist',
            args => {
                workspace_id => $foobar->workspace_id,
                page_id => 'does_not_exist',
                get_page => 1,
            },
            matcher => qr/Couldn't load page id=does_not_exist/i,
        },
    );
    for my $t (@tests) {
        diag $t->{desc};
        $jobs->clear_jobs();
        local $Socialtext::Job::Test::Retries = 2;

        my $handle = Socialtext::JobCreator->insert('Socialtext::Job::Test' => {
                %{ $t->{args} },
        });

        $jobs->can_do('Socialtext::Job::Test');
        $jobs->work_once();

        # check for permanent failure
        my @failures = $handle->failure_log;
        is scalar(@failures), 1, "one failure";
        like $failures[0], $t->{matcher}, "builder failed";
        is $handle->exit_status, 1, "has an exit_status";

        my @jobs = Socialtext::Jobs->list_jobs(
            funcname => 'Socialtext::Job::Test',
        );
        is scalar(@jobs), 0, 'perma-fail: no jobs left';
    }
};

Cant_index_untitled_page_attachments: clear_and_run {
    no warnings 'redefine';
    local *Socialtext::Attachment::load = sub { die 'do not load' };
    local *Socialtext::Attachment::temporary = sub { 1 };

    my $att = Socialtext::Attachment->new(
        hub => $hub,
        page_id => 'untitled_page',
        filename => 'foobar.txt',
    );
    ok $att, 'made attachment';

    my $handle;
    lives_ok {
        $handle = Socialtext::JobCreator->index_attachment($att, 'live')
    } 'fails silently';
    ok !$handle, 'job wasn\'t created';
};

Existing_untitled_page_jobs_fail: clear_and_run {
    use_ok 'Socialtext::Job::AttachmentIndex';

    # simulate adding a pre-existing job for untitled_page
    my $handle;
    lives_ok {
        $handle = Socialtext::JobCreator->insert(
            'Socialtext::Job::AttachmentIndex' => {
                workspace_id => $foobar->workspace_id,
                page_id => 'untitled_page',
                filename => 'foobar.txt',
                search_config => 'live',
            }
        );
    } 'insert of bad att.index job';
    ok $handle;

    $jobs->can_do('Socialtext::Job::AttachmentIndex');
    $jobs->work_once();
    {
        my @failures = $handle->failure_log;
        is scalar(@failures), 1, "one failure";
        like $failures[0], qr/Couldn't load page id=untitled_page/, 'no untitled_page for you';
        ok $handle->exit_status, "job permanently failed";
    }
};

coalescing_jobs: clear_and_run {
    Socialtext::JobCreator->insert('Socialtext::Job::Test', test => 1, job => {coalesce => 'AAA'});
    Socialtext::JobCreator->insert('Socialtext::Job::Test', test => 1, job => {coalesce => 'AAA'});
    Socialtext::JobCreator->insert('Socialtext::Job::Test', test => 1, job => {coalesce => 'BBB'});
    Socialtext::JobCreator->insert('Socialtext::Job::Test', test => 1, job => {coalesce => 'BBB'});

    is scalar($jobs->list_jobs( funcname => 'Socialtext::Job::Test' )), 4, 'start with all jobs';
    is $Socialtext::Job::Test::Work_count, 0;
   
    $jobs->can_do('Socialtext::Job::Test');
    $jobs->work_once();

    is scalar($jobs->list_jobs( funcname => 'Socialtext::Job::Test' )), 2, '2nd job completed due to coalescing key';
    is $Socialtext::Job::Test::Work_count, 1, 'only 1 of the 2 jobs "ran"';
   
    $jobs->can_do('Socialtext::Job::Test');
    $jobs->work_once();
    is scalar($jobs->list_jobs( funcname => 'Socialtext::Job::Test' )), 0, 'all done now';
    is $Socialtext::Job::Test::Work_count, 2, 'only 2 of the 4 jobs "ran"';
};

coalescing_jobs_fail: clear_and_run {
    local $Socialtext::Job::Test::Retries = 0;

    for (1..5) {
        Socialtext::JobCreator->insert('Socialtext::Job::Test', 
            test => 1, fail => 1, job => {coalesce => 'CCC'});
    }

    is scalar($jobs->list_jobs( funcname => 'Socialtext::Job::Test' )), 5, 'start with all jobs';
    is $Socialtext::Job::Test::Work_count, 0;
   
    $jobs->can_do('Socialtext::Job::Test');
    $jobs->work_once();

    is scalar($jobs->list_jobs( funcname => 'Socialtext::Job::Test' )), 0, 'all jobs got failed';
    is $Socialtext::Job::Test::Work_count, 0, 'no jobs got to work';
};

grab_for: clear_and_run {
    local $Socialtext::Job::Test::Grab_for;

    my $expected;
    my $now;
    no warnings 'once';
    no warnings 'redefine';
    local *Socialtext::Job::Test::really_work = sub {
        my $stjob = shift;
        cmp_ok $stjob->grabbed_until - $now, '>=', $expected-1,
            "job is roughly expected grab time ($expected)"
        or do {
            diag 'until:  '.$stjob->grabbed_until;
            diag 'now:    '.$now;
            diag 'expect: '.$expected;
            diag 'delta:  '.($stjob->grabbed_until - $now);
        };
    };

    $Socialtext::Job::Test::Grab_for = $expected = 60;
    Socialtext::JobCreator->insert('Socialtext::Job::Test');
    $jobs->can_do('Socialtext::Job::Test');
    $now = time;
    $jobs->work_once();
    is $Socialtext::Job::Test::Work_count, 1, "did first grabber job";

    $Socialtext::Job::Test::Grab_for = $expected = 7200;
    Socialtext::JobCreator->insert('Socialtext::Job::Test');
    $jobs->can_do('Socialtext::Job::Test');
    $now = time;
    $jobs->work_once();
    is $Socialtext::Job::Test::Work_count, 2, "did second grabber job";
};

pass 'done';

exit;

sub clear_and_run (&) {
    $Socialtext::Job::Test::Work_count = 0;
    $jobs->clear_jobs();
    goto $_[0];
}
