#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::Socialtext tests => 24;
use Test::Exception;
use Socialtext::Cache ();
use Socialtext::SQL qw(sql_execute sql_singlevalue);

fixtures('db', 'foobar');

BEGIN {
    use_ok 'Socialtext::Jobs';
    use_ok 'Socialtext::JobCreator';
    use_ok 'Socialtext::Job::Upgrade::ReparseSignalTopics';
}

my $hub = new_hub('foobar', 'system-user');
ok $hub, "loaded hub";
my $foobar = $hub->current_workspace;
ok $foobar, "loaded foobar workspace";

Socialtext::Jobs->can_do('Socialtext::Job::Upgrade::ReparseSignalTopics');
my $jobs = Socialtext::Jobs->instance;
lives_ok { $jobs->clear_jobs(); } "can clear jobs";

my $acct = create_test_account_bypassing_factory();
my $user = create_test_user(account => $acct);
$foobar->add_user(user => $user);

wikilink: {
    my $signal = Socialtext::Signal->Create(
        user => $user,
        body => "Hi there {link: foobar [test]}",
    );
    my $reply1 = Socialtext::Signal->Create(
        user => $user,
        body => "This should not have the topic!",
        in_reply_to => $signal,
    );
    my $reply2 = Socialtext::Signal->Create(
        user => $user,
        body => "But this should have the topic! {link: foobar [test]}",
        in_reply_to => $signal,
    );

    # Simulate what the old code did.
    sql_execute(qq{
        INSERT INTO topic_signal_page (signal_id, workspace_id, page_id)
        VALUES(?,?,?)
    }, $reply1->signal_id, $foobar->workspace_id, 'test');

    ok(Socialtext::JobCreator->insert(
        'Socialtext::Job::Upgrade::ReparseSignalTopics' => {}
    ), "reparse job sent");
    $jobs->work_once();

    my $has_topic = sql_singlevalue(qq{
        SELECT COUNT(*)
          FROM topic_signal_page
         WHERE signal_id = ?
    }, $signal->signal_id);
    ok $has_topic, 'wikilink signal has topic';

    $has_topic = sql_singlevalue(qq{
        SELECT COUNT(*)
          FROM topic_signal_page
         WHERE signal_id = ?
    }, $reply1->signal_id);
    ok !$has_topic, 'wikilink reply1 does not have unneeded topic';

    $has_topic = sql_singlevalue(qq{
        SELECT COUNT(*)
          FROM topic_signal_page
         WHERE signal_id = ?
    }, $reply2->signal_id);
    ok $has_topic, 'wikilink reply2 has topic';
}

weblink: {
    my $signal = Socialtext::Signal->Create(
        user => $user,
        body => "Hi there http://www.google.com",
    );
    my $reply1 = Socialtext::Signal->Create(
        user => $user,
        body => "This should not mention google.",
        in_reply_to => $signal,
    );
    my $reply2 = Socialtext::Signal->Create(
        user => $user,
        body => "This mentions http://www.google.com and http://www.yahoo.com",
        in_reply_to => $signal,
    );

    # Simulate what the old code did.
    sql_execute(qq{
        INSERT INTO topic_signal_link (signal_id, href, title)
        VALUES(?,?,?)
    }, $reply1->signal_id, 'http://www.google.com', '');

    ok(Socialtext::JobCreator->insert(
        'Socialtext::Job::Upgrade::ReparseSignalTopics' => {}
    ), "reparse job sent");
    $jobs->work_once();

    my $has_topic = sql_singlevalue(qq{
        SELECT COUNT(*)
          FROM topic_signal_link
         WHERE signal_id = ?
    }, $signal->signal_id);
    ok $has_topic, 'weblink signal has topic';

    $has_topic = sql_singlevalue(qq{
        SELECT COUNT(*)
          FROM topic_signal_link
         WHERE signal_id = ?
    }, $reply1->signal_id);
    ok !$has_topic, 'weblink reply1 does not have unneeded topic';

    $has_topic = sql_singlevalue(qq{
        SELECT COUNT(*)
          FROM topic_signal_link
         WHERE signal_id = ?
    }, $reply2->signal_id);
    is $has_topic, 2, 'weblink reply2 has correct topics';
}

