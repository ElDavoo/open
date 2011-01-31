package Socialtext::Job::Upgrade::SaveExistingDefaultDashboard;
# @COPYRIGHT@
use Moose;
use Parallel::ForkManager;
use Socialtext::SQL qw/sql_execute disconnect_dbh get_dbh/;
use Socialtext::Gadgets::Container::AccountDashboard;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

# This can take a while, especially for super huge workspaces
override 'grab_for'             => sub {3600 * 16};

# Re-parsing all the content for each page can take a long time, so
# we should not allow many of these jobs to run at the same time so that we
# do not stall the ceq queue
sub is_long_running { 1 }

# Dashboard layout to save for each account
my @old_default_gadgets = (
    {
        src => 'local:widgets:one_page',
        col => 0,
        prefs => [
            [ workspace_name => 'help' ],
            [ page_title => 'learning_resources' ],
        ],
    },
    {
        src => 'local:widgets:one_page',
        col => 0,
        prefs => [
            [ workspace_name => 'help' ],
            [ page_title => 'welcome' ],
        ],
    },
    { src => 'local:widgets:activities', col => 1 },
    { src => 'local:widgets:my_workspaces', col => 2 },
    { src => 'local:widgets:active_members', col => 2 },
    { src => 'local:widgets:top_content', col => 2 },
);

sub do_work {
    my $self = shift;

    my $sth = sql_execute('
        SELECT account_id FROM "Account"
            WHERE user_set_id NOT IN ( SELECT user_set_id FROM container );
    ');

    Socialtext::Gadgets::Gadget->Install(@old_default_gadgets);

    while (my $row = $sth->fetchrow_hashref) {
        my $account_id = $row->{account_id};
        my $container
            = Socialtext::Gadgets::Container::AccountDashboard->Fetch(
                viewer => Socialtext::User->SystemUser,
                owner  => Socialtext::Account->new(account_id => $account_id),
                name   => 'default',
                no_gadgets => 1,
            );

        for my $gadget (@old_default_gadgets) {
            Socialtext::Gadgets::GadgetInstance->Install(
                container_id => $container->container_id,
                viewer => Socialtext::User->SystemUser,
                %$gadget,
            );
        }
    }

    $self->completed();
}

__PACKAGE__->meta->make_immutable(inline_constructor => 1);
1;

=head1 NAME

Socialtext::Job::Upgrade::SaveExistingDefaultDashboard - Save existing layouts

=head1 SYNOPSIS

    use Socialtext::Migration::Utils qw/create_job/;
    create_job('SaveExistingDefaultDashboard');
    exit 0;

=head1 DESCRIPTION

Schedule a job to be run by TheCeq which will save all existing account default dashboards in their current state, since the new layou requires a central workspace that we aren't adding to existing accounts.

=cut
