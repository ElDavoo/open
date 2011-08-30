package Socialtext::Handler::Settings;
use Moose;
use Socialtext::Permission qw(ST_ADMIN_WORKSPACE_PERM ST_READ_PERM);
use Socialtext::PreferencesPlugin;
use Socialtext::l10n qw(loc);
use namespace::clean -except=>'meta';

with 'Socialtext::Handler::Base';
extends 'Socialtext::Rest::Entity';

has 'space' => (
    is => 'ro', isa => 'Maybe[Socialtext::Workspace]', lazy_build => 1);
has 'settings' => (is => 'ro', isa => 'HashRef', lazy_build => 1);

sub _build_space {
    my $self = shift;
    return eval {
        Socialtext::Workspace->new(workspace_id => $self->workspace_id)
    };
}

sub _build_settings {
    my $self = shift;

    my $user = $self->rest->user;
    my $space = $self->space;

    return $user->prefs->all_prefs unless $space;

    my $settings = 
        Socialtext::PreferencesPlugin->Workspace_user_prefs($user, $space);

    $settings->{workspaces_ui} = {
        map { $_ => $space->$_ } $self->hub->workspaces_ui->pref_names()
    };

    return $settings;
}

sub if_authorized_to_view {
    my $self = shift;
    my $callback = shift;

    return $self->not_authenticated if $self->rest->user->is_guest;
    return $callback->();
}

sub if_authorized_to_edit {
    my $self = shift;
    my $callback = shift;
    return $self->if_authorized_to_view($callback);
}

sub get_html {
    my $self = shift;
    my $rest = shift;

    my $user = $self->rest->user;
    my $prefs = $user->prefs->all_prefs;

    my $vars = $self->_settings_vars();
    $vars->{section} = 'global';
    $vars->{can_update_store} = $user->can_update_store;
    $vars->{prefs} = $self->_decorated_prefs('timezone');

    my $global = $self->render_template('element/settings/global', $vars);

    $vars->{main_content} = $global;

    return $self->render_template('view/settings', $vars);
}

around 'GET_space' => \&wrap_get;
sub GET_space { 
    my $self = shift;
    my $rest = shift;

    my $user = $self->rest->user;
    my $space = $self->space;
    return $self->error(loc('Not Found')) unless $space;

    my %abilities = $self->AdminAbilities;
    my $perm = (grep { $_ eq $self->pref } keys %abilities)
        ? ST_ADMIN_WORKSPACE_PERM
        : ST_READ_PERM;

    return $self->error(loc('Not Authorized')) unless $space->user_can(
        user => $user,
        permission => $perm,
    );

    my $vars = $self->_settings_vars();
    $vars->{section} = 'space';
    $vars->{space} = {
        auw_for => $space->is_all_users_workspace
            ? $space->account->name
            : undef,
        users => [ $space->user_roles(direct => 1)->all() ],
        groups => [ $space->group_roles(direct => 1)->all() ],
    };

    my $content;
    eval {
        $vars->{prefs} = $self->fetch_prefs();

        my $template = 'element/settings/'. $self->pref;
        $content = $self->render_template($template, $vars);
    };
    if (my $e = $@) {
        warn $e;
        return $self->error(loc('Not Found')) unless $content;
    }

    $vars->{main_content} = $content;

    $self->rest->header('Content-Type' => 'text/html; charset=utf-8');
    return $self->render_template('view/settings', $vars);
}

around 'GET_create' => \&wrap_get;
sub GET_create {
    my $self = shift;
    my $rest = shift;

    my $vars = $self->_settings_vars();
    $vars->{section} = 'create';

    my $create = $self->render_template('element/settings/create_workspace', $vars);

    $vars->{main_content} = $create;

    $self->rest->header('Content-Type' => 'text/html; charset=utf-8');
    return $self->render_template('view/settings', $vars);
}


sub fetch_prefs {
    my $self = shift;

    my $pref = $self->pref;
    my $set = {
        preferences => [qw(
            wikiwyg display email_notify
            recent_changes syndicate watchlist weblog
        )],
        features => [qw(
            workspaces_ui
        )],
    }->{$pref};

    return $self->_decorated_prefs(@$set) || {};
}

sub _decorated_prefs {
    my $self = shift;

    my $prefs = $self->_get_pref_set(@_);
    my $settings = $self->settings;

    for my $index (keys %$prefs) {
        next unless defined $settings->{$index};

        for my $key (keys %{$prefs->{$index}}) {
            next unless defined $settings->{$index}{$key};

            $prefs->{$index}{$key}{default_setting} =
                $settings->{$index}{$key};
        }
    }

    return $prefs;
}

sub _get_pref_set {
    my $self = shift;
    my @indexes = @_;

    my $prefs = {};
    $prefs->{$_} = $self->hub->$_->pref_data() for @indexes;

    return $prefs;
}

sub _settings_vars {
    my $self = shift;

    my $id = eval { $self->workspace_id };
    my $cursor = $self->rest->user->workspaces;
    my @spaces = ();
    my $i = 0;

    my $vars = {user_id => $self->rest->user->user_id};
    while (my $space = $cursor->next()) {
        $vars->{active_ix} = $i if $id && $space->workspace_id == $id;

        my $can_admin = $space->user_can(
            user => $self->rest->user,
            permission => ST_ADMIN_WORKSPACE_PERM,
        );

        push @spaces, {
            title => $space->title,
            id => $space->workspace_id,
            can_admin => $can_admin,
            active => $id && $space->workspace_id == $id ? 1 : 0,
            prefs => $self->_space_prefs($space),
        };
        $i++;
    }
    $vars->{spaces} = \@spaces;

    return $vars;
}

sub _space_prefs {
    my $self = shift;
    my $space = shift;

    my $pref = eval { $self->pref };
    my $id = eval { $self->workspace_id };

    my $is_space = $id && $space->workspace_id == $id;
    my $can_admin = $space->user_can(
        user => $self->rest->user,
        permission => ST_ADMIN_WORKSPACE_PERM,
    );

    my %abilities = (
        preferences => loc('Preferences'),
        blog => loc('Create Blog'),
        unsubscribe => loc('Unsubscribe'),
    );

    if ($can_admin) {
        %abilities = (
            %abilities,
            $self->AdminAbilities,
        );
    }

    my $prefs = [];
    for my $ability (keys %abilities) {
        my $is_ability = $pref && $ability eq $pref;
        push @$prefs, +{
            name => $ability,
            title => $abilities{$ability},
            active => $is_space && $is_ability ? 1 : 0,
        };
    }

    return $prefs;
}

sub AdminAbilities {
    return (
        manage => loc('Manage All Users'),
        # invite => loc('Invite New Users'),
        features => loc('Workspace Features'),
    );
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
