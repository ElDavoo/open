# @COPYRIGHT@
package Test::Socialtext;
use strict;
use warnings;

use lib 'lib';

use Cwd ();
use Test::Base 0.52 -Base;
use Socialtext::Base;
use Test::Builder;
use Test::Socialtext::Environment;
use Test::Socialtext::User;
use Test::Socialtext::Account;
use Test::Socialtext::Group;
use Test::Socialtext::Workspace;
use Socialtext::Account;
use Socialtext::Group;
use Socialtext::User;
use YAML;
use File::Temp qw/tempdir/;
use File::Spec;
use Socialtext::System qw/shell_run/;

BEGIN {
    use Socialtext::Pluggable::Adapter;
    use Memoize qw/unmemoize/;
    unmemoize( \&Socialtext::Pluggable::Adapter::plugins );
}

# Set this to 1 to get rid of that stupid "but matched them out of order"
# warning.
our $Order_doesnt_matter = 0;

our @EXPORT = qw(
    fixtures
    new_hub
    create_test_hub
    create_test_account
    create_test_account_bypassing_factory
    create_test_user
    create_test_workspace
    create_test_group
    SSS
    run_smarter_like
    smarter_like
    smarter_unlike
    ceqlotron_run_synchronously
    setup_test_appconfig_dir
    formatted_like
    formatted_unlike
    modules_loaded_by
);

our @EXPORT_OK = qw(
    content_pane 
    main_hub
    run_manifest
    check_manifest
);

{
    my $builder = Test::Builder->new();
    my $fh = $builder->output();
    # Get around syntax checking warnings
    if (defined $fh) {
        binmode $fh, ':utf8';
        $builder->output($fh);
    }
}

our $DB_AVAILABLE = 0;
sub fixtures () {
    $ENV{NLW_CONFIG} = Cwd::cwd . '/t/tmp/etc/socialtext/socialtext.conf';

    # set up the test environment, and all of its fixtures.
    my $env
        = Test::Socialtext::Environment->CreateEnvironment(fixtures => [@_]);

    # check to see if the "DB" fixture is current (if so, we will want to
    # store and reset some state that's inside the DB)
    $DB_AVAILABLE = Test::Socialtext::Fixture->new(name => 'db', env => $env)
        ->is_current();

    # store the state of the universe "after fixtures have been created", so
    # that we can reset back to this state (as best we can) at the end of the
    # test run.
    _store_initial_state();
}

sub run_smarter_like() {
    (my ($self), @_) = find_my_self(@_);
    my $string_section = shift;
    my $regexp_section = shift;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    for my $block ($self->blocks) {
        local $SIG{__DIE__};
        smarter_like(
            $block->$string_section,
            $block->$regexp_section,
            $block->name
        );
    }
}

sub smarter_like() {
    my $str = shift;
    my $re = shift;
    my $name = shift;
    my $order_doesnt_matter = shift || 0;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my @res = split /\n/, $re;
    for my $i (0 .. $#res) {
        my $x = qr/$res[$i]/;
        unless ($str =~ $x) {
            test_more_fail(
                "The string: '$str'\n"
                . "...doesn't match $x (line $i of regexp)",
                $name
            );
            return;
        }
    }
    my $mashed = join '.*', @res;
    $mashed = qr/$mashed/sm;
    die "This looks like a crazy regexp:\n\t$mashed is a crazy regexp"
        if $mashed =~ /\.[?*]\.[?*]/;
    if (!$order_doesnt_matter) {
        unless ($str =~ $mashed) {
            test_more_fail(
                "The string: '$str'\n"
                . "...matched all the parts of $mashed\n"
                . "...but didn't match them in order.",
                $name
            );
            return;
        }
    }
    ok 1, "$name - success";
}

sub smarter_unlike() {
    my $str = shift;
    my $re = shift;
    my $name = shift;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my @res = split /\n/, $re;
    for my $i (0 .. $#res) {
        my $x = qr/$res[$i]/;
        if ($str =~ $x) {
            test_more_fail(
                "The string: '$str'\n"
                . "...matched $x (line $i of regexp)",
                $name
            );
            return;
        }
    }
    pass( "$name - success" );
}

sub formatted_like() {
    my $wikitext = shift;
    my $re       = shift;
    my $name     = shift;
    unless ($name) {
        $name = $wikitext;
        $name =~ s/\n/\\n/g;
    }
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $formatted = main_hub()->viewer->text_to_html("$wikitext\n");
    like $formatted, $re, $name;
}

sub formatted_unlike() {
    my $wikitext = shift;
    my $re       = shift;
    my $name     = shift;
    unless ($name) {
        $name = $wikitext;
        $name =~ s/\n/\\n/g;
    }
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $formatted = main_hub()->viewer->text_to_html("$wikitext\n");
    unlike $formatted, $re, $name;
}

{
    my %module_loaded_cache;

    # get a hash-ref of modules loaded by some module
    sub modules_loaded_by {
        my $module = shift;
        unless ($module_loaded_cache{$module}) {
            my $script = 'print map { "$_\n" } keys %INC';
            my @files  = `$^X -Ilib -M$module -e '$script'`;
            if ($?) {
                croak "failed to list modules loaded by '$module'; compile error?";
            }
            chomp @files;
            map { $module_loaded_cache{$module}{$_}++ }
                map { s{\.pm$}{}; $_ }
                map { s{/}{::}g;  $_ }
                @files;
        }
        return $module_loaded_cache{$module};
    }
}

sub ceqlotron_run_synchronously() {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    require Socialtext::SQL;
    shell_run("$ENV{ST_CURRENT}/nlw/bin/ceqlotron -f -o");
    my $jobs_left = Socialtext::SQL::sql_singlevalue(q{
        SELECT COUNT(*) FROM job WHERE run_after < EXTRACT(epoch from now())
    });
    $jobs_left ||= 0;
    Test::More::is($jobs_left, 0, "ceqlotron finished all runnable jobs");
    if ($jobs_left) {
        system("ceq-read");
    }
}

# Create a temp directory and setup an AppConfig using that directory.
sub setup_test_appconfig_dir {
    my %opts = @_;

    # We want our own dir because when we try to create files later,
    # we need to make sure we're not trying to overwrite a file
    # someone else created.
    my $dir = $opts{dir} || tempdir( CLEANUP => 1 );

    # Cannot use Socialtext::File::catfile here because it depends on
    # Socialtext::AppConfig, and we don't want it reading the wrong config
    # file.
    my $config_file = File::Spec->catfile( $dir, 'socialtext.conf' );

    open(my $config_fh, ">$config_file")
        or die "Cannot open to $config_file: $!";

    select my $old = $config_fh; 
    $| = 1;  # turn on autoflush
    select $old;
    print $config_fh YAML::Dump($opts{config_data});
    close $config_fh or die "Can't write to $config_file: $!";
    return $config_file if $opts{write_config_only};

    require Socialtext::AppConfig;
    Socialtext::AppConfig->new(
        file => $config_file,
        _singleton => 1,
    );
    return $config_file;
}

# store initial state, so we can revert back to this (as best we can) at the
# end of each test run.
sub _store_initial_state {
    _store_initial_appconfig();
    if ($DB_AVAILABLE) {
        _store_initial_objects();
    }
}

# revert back to the initial state (as best we can) when the test run is over.
END { _teardown_cleanup() }
sub _teardown_cleanup {
    _reset_initial_appconfig();
    if ($DB_AVAILABLE) {
        _remove_all_but_initial_objects();
    }
}

{
    my %InitialAppConfig;
    sub _store_initial_appconfig {
        my $appconfig = Socialtext::AppConfig->new();
        foreach my $opt ($appconfig->Options) {
            $InitialAppConfig{$opt} = $appconfig->$opt();
        }
    }
    sub _reset_initial_appconfig {
        my $appconfig = Socialtext::AppConfig->new();
        foreach my $opt (keys %InitialAppConfig) {
            no warnings;
            if ($appconfig->$opt() ne $InitialAppConfig{$opt}) {
                if (Test::Socialtext::Environment->instance()->verbose) {
                    Test::More::diag("CLEANUP: resetting '$opt' AppConfig "
                                    ."value; your test changed it");
                }
                $appconfig->set( $opt, $InitialAppConfig{$opt} );
                $appconfig->write();
            }
        }
    }
}

{
    my %Initial;
    my %Objects = (
        user => {
            get_iterator => sub { Socialtext::User->All() },
            get_id       => sub { $_[0]->user_id },
            identifier   => sub {
                my $u = shift;
                return $u->driver_name . ':' . $u->user_id
                     . ' (' . $u->username . ')';
            },
            delete_item => sub {
                Test::Socialtext::User->delete_recklessly($_[0]);
            }
        },
        workspace => {
            get_iterator => sub { Socialtext::Workspace->All() },
            get_id       => sub { $_[0]->workspace_id },
            identifier   => sub {
                my $w = shift;
                return $w->workspace_id . ' (' . $w->name . ')';
            },
            delete_item => sub {
                Test::Socialtext::Workspace->delete_recklessly($_[0]);
            },
        },
        account => {
            get_iterator => sub { Socialtext::Account->All() },
            get_id => sub { $_[0]->account_id },
            identifier => sub {
                my $a = shift;
                return $a->account_id . ' (' . $a->name . ')';
            },
            delete_item => sub {
                Test::Socialtext::Account->delete_recklessly($_[0]);
            },
        },
        role => {
            get_iterator => sub { Socialtext::Role->All() },
            get_id       => sub { $_[0]->role_id },
            identifier   => sub {
                my $r = shift;
                return $r->role_id . ' (' . $r->name . ')';
            },
            delete_item => sub { $_[0]->delete },
        },
        group => {
            get_iterator => sub { Test::Socialtext::Group->All() },
            get_id       => sub { $_[0]->group_id },
            identifier   => sub {
                my $g = shift;
                return $g->group_id . ' (' . $g->driver_group_name . ')';
            },
            delete_item  => sub {
                Test::Socialtext::Group->delete_recklessly($_[0]);
            },
        }
    );

    sub _store_initial_objects {
        while (my ($key,$obj) = each %Objects) {
            my $iterator = $obj->{get_iterator}->();
            while (my $item = $iterator->next()) {
                my $id = $obj->{get_id}->($item);
                $Initial{$key}{$id} ++;
            }
        }
    }

    sub _remove_all_but_initial_objects {
        while (my ($key,$obj) = each %Objects) {
            my $iterator = $obj->{get_iterator}->();
            if (Test::Socialtext::Environment->instance()->verbose) {
                Test::More::diag("CLEANUP: removing ${key}s");
            }
            while (my $item = $iterator->next()) {
                # remove all but the initial set of objects that were
                # created and available at startup.
                my $id = $obj->{get_id}->($item);
                next if $Initial{$key}{$id};

                # Delete it
                if (Test::Socialtext::Environment->instance()->verbose) {
                    my $identifier = $obj->{identifier}->($item);
                }
                $obj->{delete_item}->($item);
            }
        }

        if (Test::Socialtext::Environment->instance()->verbose) {
            Test::More::diag("CLEANUP: removing all ceq jobs");
        }
        Socialtext::SQL::sql_begin_work();
        # OK to leave funcmap alone
        Socialtext::SQL::sql_execute(
            "TRUNCATE note, error, exitstatus, job"
        );
        Socialtext::SQL::sql_commit();
    }
}

sub test_more_fail() {
    my $str = shift;
    my $test_name = shift || '';
    warn $str; # This doesn't get shown unless in verbose mode.
    Test::More::fail($test_name); # to get the counts right.
}

sub run_manifest() {
    (my ($self), @_) = find_my_self(@_);
    for my $block ($self->blocks) {
        $self->check_manifest($block) 
          if exists $block->{manifest};
    }
}

sub check_manifest {
    my $block = shift;
    my @manifest = $block->manifest;
    my @unfound = grep not(-e), @manifest;
    my $message = 'expected files exist';
    if (@unfound) {
        warn "$_ does not exist\n" for @unfound;
        $message = sprintf "Couldn't find %s of %s paths\n",
          scalar(@unfound),
          scalar(@manifest);
    }
    ok(0 == scalar @unfound, $message);
}

sub new_hub() {
    no warnings 'once';
    my $name     = shift or die "No name provided to new_hub\n";
    my $username = shift;

    Test::Socialtext::ensure_workspace_with_name($name);

    my $hub = Test::Socialtext::Environment->instance()->hub_for_workspace($name, $username);
    $Test::Socialtext::Filter::main_hub = $hub;
    return $hub;
}

sub ensure_workspace_with_name() {
    my $name = shift;
    return if Socialtext::Workspace->new( name => $name );

    create_test_workspace( unique_id => $name );
    return;
}

my $main_hub;

sub main_hub {
    $main_hub = shift if @_;
    $main_hub ||= Test::Socialtext::new_hub('admin');
    return $main_hub;
}

{
    my $counter = 0;
    sub create_unique_id {
        my $id = time . $$ . $counter;
        $counter++;
        return $id;
    }

    sub create_test_account {
        my $unique_id = shift || create_unique_id;
        my $hub       = main_hub();
        return $hub->account_factory->create( name => $unique_id );
    }

    sub create_test_account_bypassing_factory {
        my $unique_id = shift || create_unique_id;
        return Socialtext::Account->create(name => $unique_id);
    }

    sub create_test_user {
        my %opts = @_;
        $opts{unique_id}          ||= create_unique_id;
        $opts{account}            ||= Socialtext::Account->Default;
        $opts{created_by_user_id} ||= Socialtext::User->SystemUser->user_id;
        my $user = Socialtext::User->create(
            username           => $opts{unique_id} . '@ken.socialtext.net',
            email_address      => $opts{unique_id} . '@ken.socialtext.net',
            created_by_user_id => $opts{created_by_user_id},
        );
        $user->primary_account($opts{account}->account_id);
        return $user;
    }

    sub create_test_workspace {
        my %opts = @_;

        $opts{unique_id} ||= create_unique_id;
        $opts{account} ||= Socialtext::Account->Default;
        $opts{user} ||= Socialtext::User->SystemUser;

        # create a new test Workspace
        my $ws = Socialtext::Workspace->create(
            name               => $opts{unique_id},
            title              => $opts{unique_id},
            created_by_user_id => $opts{user}->user_id,
            account_id         => $opts{account}->account_id,
            skip_default_pages => 1,
        );
    }

    sub create_test_group {
        my %opts = @_;
        $opts{unique_id} ||= create_unique_id;
        $opts{account}   ||= Socialtext::Account->Default;
        $opts{user}      ||= Socialtext::User->SystemUser;

        my $group = Socialtext::Group->Create( {
            driver_group_name  => $opts{unique_id},
            created_by_user_id => $opts{user}->user_id,
            primary_account_id => $opts{account}->account_id,
        } );
    }

    sub create_test_hub {
        my $unique_id = create_unique_id;

        # create a new test User
        my $user = create_test_user(unique_id => $unique_id);
        my $ws = create_test_workspace(unique_id => $unique_id, user => $user);

        # create a Hub based on this User/Workspace
        return new_hub($ws->name, $user->username);
    }
}

sub SSS() {
    my $sh = $ENV{SHELL} || 'sh';
    system("$sh > `tty`");
    return @_;
}

package Test::Socialtext::Filter;
use strict;
use warnings;

use base 'Test::Base::Filter';

# Add Test::Base filters that are specific to NLW here. If they are really
# generic and interesting I'll move them into Test::Base

sub interpolate_global_scalars {
    map {
        s/"/\\"/g;
        s/@/\\@/g;
        $_ = eval qq{"$_"};
        die "Error interpolating '$_': $@" 
          if $@;
        $_;
    } @_;
}

sub tmp_nlwroot_path {
    map { 't/tmp/' . $_ } @_;
}

# Regexps with the '#' character seem to get messed up.
sub literal_lines_regexp {
    $self->assert_scalar(@_);
    my @lines = $self->lines(@_);
    @lines = $self->chomp(@lines);
    my $string = join '', map {
        # REVIEW: This is fragile and needs research.
        s/([\$\@\}])/\\$1/g;
        "\\Q$_\\E.*?\n";
    } @lines;
    my $flags = $Test::Base::Filter::arguments;
    $flags = 'xs' unless defined $flags;

    my $regexp = eval "qr{$string}$flags";
    die $@ if $@;
    return $regexp;
}

sub wiki_to_html {
    $self->assert_scalar(@_);
    Test::Socialtext::main_hub()->formatter->text_to_html(shift);
}

sub wrap_p_tags {
    $self->assert_scalar(@_);
    sprintf qq{<p>\n%s<\/p>\n}, shift;
}

sub wrap_wiki_div {
    $self->assert_scalar(@_);
    sprintf qq{<div class="wiki">\n%s<\/div>\n}, shift;
}

sub new_page {
    $self->assert_scalar(@_);
    my $hub = Test::Socialtext::main_hub();
    my $page = $hub->pages->new_page_from_any(shift);
    $page->metadata->update( user => $hub->current_user );
    return $page;
}

sub store_new_page {
    $self->assert_scalar(@_);
    my $page = $self->new_page(shift);
    $page->store( user => Test::Socialtext::main_hub()->current_user );
    return $page;
}

sub content_pane {
    my $html = shift;
    $html =~ s/
        .*(
        <div\ id="page-container">
        .*
        <td\ class="page-center-control-sidebar-cell"
        ).*
    /$1/xs;
    $html
}

sub _cleanerr() {
    my $output = shift;
    $output =~ s/^.*index.cgi: //gm;
    my @lines = split /\n/, $output;
    pop @lines;
    if (@lines > 15) {
        push @lines, "\n...more above\n", @lines[0..15]
    }
    join "\n", @lines;
}

1;

