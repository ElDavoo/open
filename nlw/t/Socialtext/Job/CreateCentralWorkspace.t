#!perl
# @COPYRIGHT@
use strict;
use warnings;
use Socialtext::Jobs;
use Socialtext::JobCreator;
use Test::More;
use Test::Socialtext;

# We want a db, but _no_ ceq jobs.
fixtures( qw(db no-ceq-jobs) );

my $class = 'Socialtext::Job::CreateCentralWorkspace';
use_ok $class;

# Register workers
Socialtext::Jobs->can_do($class);

sub create_central_workspace_ok {
    my $acct      = shift;
    my $acct_name = $acct->name;

    Socialtext::JobCreator->insert(
        'Socialtext::Job::CreateCentralWorkspace', {
            account_id => $acct->account_id,
        }
    );

    ceqlotron_run_synchronously($class, undef, 1);

    # Refresh the account
    $acct = Socialtext::Account->new(name => $acct_name);

    my $wksp_name = $acct->plugin_preferences->{widgets}{central_workspace};
    ok $wksp_name, "central_workspace plugin_preference is set";

    my $wksp = Socialtext::Workspace->new(name => $wksp_name);
    ok $wksp, "Account has central workspace '$wksp_name'";

    # Workspace is an AUW
    ok $wksp->is_all_users_workspace, "workspace is AUW";
    ok $acct->has_all_users_workspaces, 'account has AUWs';
    ok $wksp->has_account($acct), 'workspace has account as member';

    # Default pages exist
    my @pages = (
        "I'm new. What do I do?",
        'news_and_announcements',
        $wksp_name,
    );
    my ($main, $hub) = $wksp->_main_and_hub();
    for my $name (@pages) {
        my $page = $hub->pages->new_from_name($name);
        ok $page->exists, "$name exists";
        ok $page->content, "$name has content";
    }

    return $wksp;
}

################################################################################
creating_account_creates_wksp: {
    diag "Creating a new Account creates an AUW";

    my $acct      = create_test_account_bypassing_factory();
    my $acct_name = $acct->name;

    ceqlotron_run_synchronously($class, undef, 1);

    my $wksp = Socialtext::Workspace->new(name => "${acct_name}_central");
    ok $wksp, "Workspace exists after job runs";
 
    ok $wksp->has_account($acct),
        'Ensure the workspace is a "all users workspace"';

    is $acct->plugin_preferences->{widgets}{central_workspace},
        "${acct_name}_central", "Plugin preference is set properly";
}

upgrading_account_creates_wksp: {
    diag "Upgrading account creates a new AUW";

    my $acct = create_test_account_bypassing_factory(undef, 
        no_plugin_hooks => 1,
    );
    my $acct_name = $acct->name;

    my $job = Socialtext::Jobs->find_job_for_workers();
    ok !$job, 'No job';
    
    # confirm no central workspace
    ok !$acct->plugin_preferences->{widgets}{central_workspace},
        "Plugin preference is set properly";

    my $wksp = create_central_workspace_ok($acct);

    is $wksp->name, "${acct_name}_central",
        "Plugin preference is set properly";
}

upgrading_account_uses_preexisting_auw: {
    diag "Upgrading account uses the pre-existing AUW";

    my $acct = create_test_account_bypassing_factory(undef, 
        no_plugin_hooks => 1,
    );
    my $acct_name = $acct->name;

    my $job = Socialtext::Jobs->find_job_for_workers();
    ok !$job, 'No job';

    # Give this acct an AUW
    my $wksp_name = 'awesome_' . time . $$;
    my $wksp = create_test_workspace(
        unique_id => $wksp_name,
        account => $acct,
    );
    $wksp->assign_role_to_account(account => $acct);

    # Edit a page so we can make sure it isn't clobbered
    my ($main, $hub) = $wksp->_main_and_hub();
    Socialtext::Page->new(hub => $hub)->create(
        title => "News and Announcements",
        content => "test content",
        creator => Socialtext::User->SystemUser,
        categories => [],
    );

    # confirm no central workspace
    ok !$acct->plugin_preferences->{widgets}{central_workspace},
        "Plugin preference is set properly";

    $wksp = create_central_workspace_ok($acct);

    # The original workspace should be chosen, a new one wasn't created
    isnt $wksp->name, "${acct_name}_central",
        "Plugin preference is set properly";
    is $wksp->name, $wksp_name, "Plugin preference is set properly";

    # The News and Announcements page should still have the original content
    my $page = $hub->pages->new_from_name('News and Announcements');
    ok $page->exists, 'Page exists';
    is $page->content, "test content\n", 'Page content is correct';
}

done_testing;
