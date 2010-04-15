#!perl
use warnings;
use strict;
# @COPYRIGHT@
use Test::More tests => 38;
use AnyEvent;
use Coro;
use Coro::AnyEvent;

use ok 'Socialtext::Async::WorkQueue';

empty: {
    my $q = Socialtext::Async::WorkQueue->new(
        name => 'empty',
        cb => sub { },
    );
    ok $q;
    eval { $q->shutdown };
    ok !$@, "shutdown ok";
}

normal: {
    my @order1;
    my $q1 = Socialtext::Async::WorkQueue->new(
        name => 'queue one',
        cb => sub {
            my $n = shift;
            cede if rand > 0.2;
            push @order1, "one $n";
            pass "one $n";
        },
    );
    ok $q1;

    my @order2;
    my $q2 = Socialtext::Async::WorkQueue->new(
        name => 'queue two',
        cb => sub {
            my $n = shift;
            cede if rand > 0.9;
            push @order2, "two $n";
            pass "two $n";
        },
    );
    ok $q2;
    cede if rand > 0.3;
    ok !@order1;
    ok !@order2;

    for my $x (1..5) {
        $q1->enqueue([$x]);
        cede if rand > 0.5;
        $q2->enqueue([$x]);
        cede if rand > 0.4;
    }

    $q1->shutdown();
    $q2->shutdown();

    is_deeply \@order1, [map { "one $_" } 1..5], "all of one looks good";
    is_deeply \@order2, [map { "two $_" } 1..5], "all of two looks good";
}

timeout: {
    my $bad = Socialtext::Async::WorkQueue->new(
        name => 'bad',
        cb => sub {
            pass 'work on bad job';
            Coro::AnyEvent::sleep 10;
        }
    );
    $bad->enqueue(['anything']);
    eval {
        $bad->shutdown(1.0);
    };
    like $@, qr/timeout/, "flush timeout";
}

recursive: {
    my $todo = 1;
    my $sync = Coro::rouse_cb;
    my $q; $q = Socialtext::Async::WorkQueue->new(
        name => 'recursive',
        cb => sub {
            my $ok = shift;
            is $ok, 'alright', "recursive call alright";
            if ($todo) {
                $todo = 0;
                pass 'first pass, queue still active';
                ok $q->enqueue(['alright','a job']),
                    "queued a job from within runner";
                eval { $q->shutdown };
                ok $@, 'cannot shutdown queue from runner thread';
                $sync->();
            }
            else {
                my $cluck;
                local $SIG{__WARN__} = sub {
                    $cluck = shift;
                };
                pass 'second pass, queue should already be shut down';
                ok !$q->enqueue(['bad','should not run']),
                    "didn't queue a job";
                like $cluck, qr/attempt to enqueue job.+after shutdown/,
                    "emits warning when enqueueing job after shutdown";
            }
        }
    );
    $q->enqueue(['alright','first job']);
    pass 'enqueued first recursive job';
    Coro::rouse_wait $sync;
    pass 'sync to shut down';
    $q->shutdown();
}

shutdown_chain: {
    my $top_cv = AE::cv;
    $top_cv->begin;
    my $got_after = 0;
    my $chain = Socialtext::Async::WorkQueue->new(
        name => 'chain',
        cb => sub {
            pass 'work on chain job';
        },
        after_shutdown => sub {
            pass 'after shutdown';
            $got_after = 1;
            $top_cv->end;
        }
    );
    $chain->enqueue(['job']);
    $chain->enqueue(['job 2']);
    $chain->shutdown_nowait();
    $top_cv->recv;
    is $got_after, 1, 'chained shutdown';
}

cancel: {
    my $worked_on = 0;
    my $q; $q = Socialtext::Async::WorkQueue->new(
        name => 'for_cancelling',
        cb => sub {
            pass 'work on just one job';
            $worked_on++;
            $q->drop_pending();
        },
    );
    $q->enqueue(['job 1']);
    $q->enqueue(['job 2']);
    $q->enqueue(['job 3']);
    $q->shutdown();
    is $worked_on, 1, 'worked on exactly one job';
}

pass 'all done';
