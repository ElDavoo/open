package Socialtext::Job::CreateCentralWorkspace;
# @COPYRIGHT@
use Moose;
use Socialtext::SQL qw/sql_execute/;
use Socialtext::User;
use Socialtext::Workspace;
use Socialtext::PrefsTable;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

sub do_work {
    my $self = shift;

    my $user = Socialtext::User->SystemUser();

    # Find a valid name
    my ($title, $name, $ws);
    for (my $i = 0; !$i or defined $ws; $i++) {
        # XXX: Horrible for i18n:
        my $suffix = ' Central' . ($i ? " $i" : "");
        $title = $self->account->name . $suffix;
        $name = Socialtext::String::title_to_id($title);

        $name =~ s/^st_//;
        if ( Socialtext::Workspace->NameIsIllegal($name) ) {
            # This can only be because the name is too long

            # Truncate the account name, saving room for $suffix
            $name = substr($self->account->name, 0, 30 - length($suffix));
            $name = Socialtext::String::title_to_id($name . $suffix);
        }

        $ws = Socialtext::Workspace->new(name => $name)
    }

    my $wksp = Socialtext::Workspace->create(
        name                => $name,
        title               => $title,
        account_id          => $self->account->account_id,
        created_by_user_id  => $user->user_id(),
        allows_page_locking => 1,
    );

    $wksp->assign_role_to_account(account => $self->account);

    my $share_dir = Socialtext::AppConfig->new->code_base();
    $wksp->load_pages_from_disk(
        dir => "$share_dir/workspaces/central",
        replace => {
            # Replace all pages with YourCo in the title with this account's
            # name
            'YourCo' => $self->account->name,
        },
    );

    # Enable the widgets plugin so we can set this preference
    $self->account->enable_plugin('widgets');

    # Store the name of the workspace
    my $pref_table = Socialtext::PrefsTable->new(
        table    => 'user_set_plugin_pref',
        identity => {
            plugin      => 'widgets',
            user_set_id => $self->account->user_set_id,
        },
    );
    $pref_table->set(central_workspace => $name);

    $self->completed();
}

__PACKAGE__->meta->make_immutable(inline_constructor => 1);
1;

=head1 NAME

Socialtext::Job::CreateCentralWorkspace - Save old layouts

=head1 SYNOPSIS

    use Socialtext::Migration::Utils qw/create_job/;
    create_job('CreateCentralWorkspace', 31, no_upgrade => 1);
    exit 0;

=head1 DESCRIPTION

Schedule a job to be run by TheCeq which will save the old default dashboard for each existing account.

=cut
