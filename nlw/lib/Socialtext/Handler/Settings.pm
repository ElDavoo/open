package Socialtext::Handler::Settings;
use Moose;
use Socialtext::Permission qw(ST_ADMIN_WORKSPACE_PERM);
use Socialtext::l10n qw(loc);
use namespace::clean -except=>'meta';

with 'Socialtext::Handler::Base';
extends 'Socialtext::Rest::Entity';

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

    my $timezone = $self->hub->timezone;
    my $zones = $timezone->zones;
    $vars->{prefs}{time} = {
        user => $prefs->{timezone},
        zones => $timezone->timezone_options,
        formats => $timezone->date_display_options,
        dst => $timezone->dst_options,
        times_12_24 => $timezone->time_display_options,
        times_seconds => $timezone->seconds_options,
    };

    my $global = $self->render_template('element/settings/global', $vars);
    $vars->{main_content} = $global;
    return $self->render_template('view/settings', $vars);
}

around 'GET_space' => \&wrap_get;
sub GET_space { 
    my $self = shift;
    my $rest = shift;

    my $vars = $self->_settings_vars();
    $vars->{section} = 'space';

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
            manage => loc('Manage All Users'),
            invite => loc('Invite New Users'),
            features => loc('Workspace Features'),
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

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
