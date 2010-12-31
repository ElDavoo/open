#!/usr/bin/env perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext::Fatal;
use Test::Socialtext tests => 9;
use Test::Socialtext::Search;
use File::Basename qw(basename);
use Socialtext::Jobs;
use Socialtext::JobCreator;
use Socialtext::Job::Upgrade::IndexOffice2007PageAttachments;

fixtures(qw( db ));

# TEST: Office 2007 docs get scheduled for re-index
schedule_for_reindex: {
    my $hub = create_test_hub();
    Test::Socialtext->main_hub($hub);

    my $page_name = 'Test Page';
    my $page_id   = 'test_page';

    # create a page
    create_and_confirm_page($page_name, 'with some dummy content');

    # give it some attachments; some ofc2007, some not
    my @atts_other = qw(
        t/Socialtext/File/stringify_data/test.txt
        t/Socialtext/File/stringify_data/test.pdf
        t/Socialtext/File/stringify_data/sample.doc
        t/Socialtext/File/stringify_data/sample.dotx
    );
    my @atts_2007 = qw(
        t/Socialtext/File/stringify_data/sample.docx
        t/Socialtext/File/stringify_data/sample.xlsx
        t/Socialtext/File/stringify_data/sample.pptx
    );
    my @all_attachments = (@atts_other, @atts_2007);
    foreach my $att (@all_attachments) {
        my $filename = basename($att);

        open my $fh, $att or die "unable to open $att; $!";
        $hub->attachments->create(
            page_id  => $page_id,
            filename => $filename,
            fh       => $fh,
            creator  => $hub->current_user,
        );
    }

    # verify that we've got the right number of attachments
    my $attached = $hub->attachments->all(page_id => $page_id);
    is @{$attached}, @all_attachments, 'got right # of attachments';


    # clear Ceq queue
    ok !exception { Socialtext::Jobs->clear_jobs() }, 'cleared out queued jobs';

    # run the upgrade job
    my $upgrade_job_type = 'Socialtext::Job::Upgrade::IndexOffice2007PageAttachments';
    my $index_job_type   = 'Socialtext::Job::AttachmentIndex';
    Socialtext::Jobs->can_do($upgrade_job_type);
    Socialtext::Jobs->can_do($index_job_type);
    Socialtext::JobCreator->insert($upgrade_job_type, {
        workspace_id => $hub->current_workspace->workspace_id,
    } );

    my $job = Socialtext::Jobs->find_job_for_workers();
    ok $job, 'upgrade job was added to queue';

    my $rc  = Socialtext::Jobs->work_once($job);
    ok $rc,  'upgrade job completed';
    is $job->exit_status, 0, '... successfully';

    # verify the stuff left in the Ceq queue as jobs
    my @jobs = Socialtext::JobCreator->list_jobs(
        funcname => $index_job_type,
    );
    is @jobs, @atts_2007, 'right number of attachment index jobs';

    # verify that the Attachments being re-index are the Office 2007 ones
    my @orig_attach_ids =
        sort
        map { $_->id }
        grep { $_->filename =~ /(doc|xls|ppt)x$/ }
        @{$attached};
    my @job_attach_ids = sort map { $_->arg->{attach_id} } @jobs;

    is_deeply \@job_attach_ids, \@orig_attach_ids,
        '... with the correct attachment ids';
}
