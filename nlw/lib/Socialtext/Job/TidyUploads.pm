package Socialtext::Job::TidyUploads;
# @COPYRIGHT@
use Moose;
use Socialtext::SQL qw/sql_execute sql_txn/;
use Socialtext::Upload;

extends 'Socialtext::Job';
with 'Socialtext::CoalescingJob';

use constant AT_A_TIME => 100; # just to limit the run-time of the select

sub do_work {
    my $self = shift;

    my $referenced = join "\nOR\n", map {
#         "EXISTS (SELECT 1 FROM $_ 
#                  WHERE $_.attachment_id = attachment.attachment_id)";
          "attachment_id IN (SELECT attachment_id FROM $_)"
    } Socialtext::Upload::TABLE_REFS;

    my $sth = sql_execute(qq{
        SELECT attachment_id FROM attachment a
        WHERE NOT ( $referenced )
        LIMIT ?
    }, AT_A_TIME);

    return $self->success if $sth->rows == 0;

    while (my $row = $sth->fetchrow_arrayref) {
        my $att_id = $row->[0];
        # run in a txn to avoid conflicts with things picking abandoned rows
        sql_txn {
            sql_execute(q{
                DELETE FROM attachment WHERE attachment_id = ?
            }, $att_id)
        };
    }

    # Check again in FREQUENCY seconds.  We'll stop when there's no more work
    # to do.
    my $next = TheSchwartz::Moosified::Job->new({
        run_after => time + Socialtext::Upload::TIDY_FREQUENCY,
        (map { $_ => $self->job->$_ }
         qw(funcid funcname priority uniqkey coalesce)),
    });
    $self->job->replace_with($next);
}
