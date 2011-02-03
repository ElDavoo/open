#!perl
use warnings;
use strict;
use Test::Socialtext tests => 28;
use Test::Socialtext::Fatal;
use Socialtext::SQL qw/:txn/;
use File::Temp qw/tempdir tempfile/;
use File::Copy qw/copy move/;

use ok 'Socialtext::Upload';

fixtures(qw(db));

my $user = create_test_user();
my $tmp = File::Temp->new(CLEANUP => 1);
print $tmp "Some attachment data $^T\n";
close $tmp;

my $ul;
is exception { 
    $ul = Socialtext::Upload->Create(
        creator => $user,
        temp_filename => "$tmp",
        filename => "fancy-pants.txt",
        mime_type => 'text/plain; charset=UTF-8',
    );
}, undef, "created upload";
isa_ok $ul, 'Socialtext::Upload';
ok $ul->is_temporary, "is temporary";
is $ul->filename, "fancy-pants.txt";

check_temp_upload: {
    is $ul->disk_filename, $ul->temp_filename;
    ok -f $ul->temp_filename, "temp upload exists";
    my $data = do { local (@ARGV,$/) = ($ul->temp_filename); <> };
    is $data, "Some attachment data $^T\n", "temp contents good";
}

make_permanent_fails: {
    # the idea here is that the calling code will stage the upload then try to
    # do something else.  If that fails, the guard is triggered, otherwise the
    # caller should ->cancel the guard.
    is exception {
        sql_txn {
            my $guard = $ul->make_permanent(guard=>1);
            die "rollback\n";
        };
    }, "rollback\n";
    ok $ul->is_temporary;
    ok !-f $ul->storage_filename, "file didn't get written to storage";
    ok -f $ul->temp_filename, "tempfile is still present";
}

make_permanent: {
    is exception {
        $ul->make_permanent();
    }, undef, "made permanent";
    ok !$ul->is_temporary, "no longer temporary";
    is $ul->disk_filename, $ul->storage_filename;
    ok !-f $ul->temp_filename, "tempfile is gone";

    ok -f $ul->storage_filename, "make_permanent cached contents to disk";
    my $data = do { local (@ARGV,$/) = ($ul->disk_filename); <> };
    is $data, "Some attachment data $^T\n", "slurped contents are good";

    my $data2;
    $ul->binary_contents(\$data2);
    is $data2, "Some attachment data $^T\n", "binary contents are good";
}

ensure_stored: {
    my $dir = tempdir(CLEANUP => 1);
    local $Socialtext::Upload::STORAGE_DIR = "$dir";
    like $ul->storage_filename, qr{^\Q$dir}, "storage filename reflects local";
    ok !-f $ul->storage_filename, "upload isn't on disk";
    is $ul->disk_filename, $ul->storage_filename;

    is exception { $ul->ensure_stored }, undef, "ensured storage";
    ok -f $ul->disk_filename && -s _, "upload restored to disk";
    my $data = do { local (@ARGV,$/) = ($ul->disk_filename); <> };
    is $data, "Some attachment data $^T\n", "stored contents are good";

    unlink $ul->disk_filename;
    my $data2;
    $ul->binary_contents(\$data2);
    is $data2, "Some attachment data $^T\n", "blob is good (auto vivified)";
    ok !-f $ul->storage_filename, "upload NOT restored by binary_contents";
}

pass "done";
