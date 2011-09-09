package Socialtext::Handler::Settings;
use Moose;
use Socialtext::Permission qw(ST_ADMIN_WORKSPACE_PERM ST_READ_PERM
                              ST_EMAIL_IN_PERM ST_EDIT_PERM);
use Socialtext::Role;
use Socialtext::PreferencesPlugin;
use Socialtext::PrefsTable;
use Socialtext::l10n qw(loc);
use Socialtext::Log qw(st_log);
use namespace::clean -except=>'meta';
use Socialtext::Exceptions qw(email_address_exception user_exception);

with 'Socialtext::Handler::Base';
extends 'Socialtext::Rest::Entity';

has 'space' => (
    is => 'ro', isa => 'Maybe[Socialtext::Workspace]', lazy_build => 1);
has 'settings' => (is => 'ro', isa => 'HashRef', lazy_build => 1);
has 'message' => (is => 'rw', isa => 'Str', default => '');
has 'invite_errors' => (is => 'rw', isa => 'Maybe[HashRef]', default => undef);

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

sub POST {
    my $self = shift;
    my $rest = shift;

    return $self->not_authenticated if $self->rest->user->is_guest;

    eval {
        my $user = $self->rest->user;
        my $q = $self->rest->query;
        my $new_password = $q->param('user.new_password');

        if ($new_password) {
            if (!$user->password_is_correct($q->param('user.old_password'))) {
                $self->message(loc('Current password not correct'));
            }
            elsif ($new_password ne $q->param('user.new_password_retype')) {
                $self->message(loc('New password does not match'));
            }
            else {
                my @messages = $user->ValidatePassword(password => $new_password);
                $self->message($messages[0]) if (scalar(@messages));
            }
            return $self->get_html($rest) if ($self->message);
        }
        
        if ($user->can_update_store) {
            my %p = (
                first_name => $q->param('user.first_name'),
                last_name => $q->param('user.last_name'),
                middle_name => $q->param('user.middle_name'),
            );
            $p{password} = $new_password if ($new_password);
            $user->update_store(%p);
        }

        my @params = $self->hub->timezone->pref_names;
        my $prefs = {
            map { $_ => $q->param("prefs.timezone.$_") || '0'} @params
        };
        $user->prefs->save({timezone => $prefs});

        my $plugin_prefs = {};

        @params = grep { /^checkbox\.plugin\./ } $q->param;
        for my $param (@params) {
            my (undef,undef,$plugin,$pref) = split(/\./, $param);
            $plugin_prefs->{$plugin}{$pref} = $q->param($param);
        }

        @params = grep { /^plugin\./ } $q->param;
        for my $param (@params) {
            my (undef,$plugin,$pref) = split(/\./, $param);
            $plugin_prefs->{$plugin}{$pref} = $q->param($param);
        }

        for my $plugin (keys %$plugin_prefs) {
            my $prefs = $self->_plugin_prefs_table($plugin);
            $prefs->set(%{ $plugin_prefs->{$plugin} });
        }

        $self->message(loc('Saved')) unless $self->message;
    };
    if (my $e = $@) {
        st_log->error("Could not save settings: $e");
        $self->message(loc('Error when saving settings'));
    }

    return $self->get_html($rest);
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


sub POST_space {
    my $self = shift;
    my $rest = shift;

    return $self->error(loc('Not Found')) unless $self->space;
    return $self->error(loc('Not Authorized'))
        unless $self->_user_has_correct_perms;

    my $q = $self->rest->query;

    my $settings = {};
    for my $box (grep { /^checkbox\./ } $q->param) {
        my (undef,$object,$index,$value) = split(/\./, $box);
        $settings->{$object}{$index}{$value} = $q->param($box);
    }

    for my $setting (grep { !/^checkbox\./ } $q->param) {
        my ($object,$index,$value) = split(/\./, $setting);
        $settings->{$object}{$index}{$value} = $q->param($setting);
    }

    my $redirect = '';
    eval {
        $self->hub->current_workspace($self->space);
        if (my $space_settings = $settings->{workspace}) {
            $self->space->update(%{$space_settings->{setting}})
                if $space_settings->{setting};

            my $email_in = $space_settings->{permission}{guest_has_email_in};
            if (defined $email_in) {
                if ($email_in) {
                    $self->space->permissions->add(
                        permission => ST_EMAIL_IN_PERM,
                        role => Socialtext::Role->Guest,
                    );
                }
                else {
                    $self->space->permissions->remove(
                        permission => ST_EMAIL_IN_PERM,
                        role => Socialtext::Role->Guest,
                    );
                }
            }

            if (my @valid = $q->param('workspace.do.valid_user')) {
                my @remove = $q->param('workspace.do.remove_user');
                my @admins = $q->param('workspace.do.should_be_admin');
                my @password_reset = $q->param('workspace.do.reset_password');

                my $admin = Socialtext::Role->Admin;
                my $member = Socialtext::Role->Member;

                foreach my $ids (@valid) {
                    my ($user_id, $role_id) = split /\./, $ids;
                    
                    my $needs_reset = grep { $user_id eq $_ } @password_reset; 
                    my $needs_removal = grep { $user_id == $_ } @remove;
                    my $be_admin = grep { $user_id eq $_ } @admins;
                    my $role_changed = $be_admin
                        ? $role_id == $member->role_id
                        : $role_id == $admin->role_id;

                    next unless $needs_reset or $needs_removal or $role_changed;

                    my $user = Socialtext::User->new(user_id => $user_id);
                    next unless $user;
                    next unless $self->space->has_user($user, direct => 1);

                    if ($needs_removal) {
                        $self->space->remove_user(
                            user => $user,
                            actor => $self->rest->user,
                        );
                        $redirect = '/st/settings'
                            if $user->user_id == $self->rest->user->user_id;
                        next;
                    }

                    if ($needs_reset) {
                        my $confirmation =
                            $user->create_password_change_confirmation;
                        $confirmation->send;
                    }

                    if ($role_changed) {
                        if ($be_admin) {
                            $self->space->assign_role_to_user(
                                user => $user,
                                role => $admin,
                                actor => $self->rest->user,
                            );
                        } else {
                            $self->space->assign_role_to_user(
                                user => $user,
                                role => $member,
                                actor => $self->rest->user,
                            );
                            $redirect = '/st/settings'
                                if $user->user_id == $self->rest->user->user_id;
                        }
                    }
                }
            }

            if (my @invitees = $q->param('workspace.do.invite_user')) {
                my %bad_users = ();
                for my $invite (@invitees) {
                    eval {
                        my $proto = $invite =~ /^\d+$/
                            ? Socialtext::User->GetProtoUser(user_id => $invite)
                            : Socialtext::User->GetProtoUser(email_address => $invite);
                        $proto ||= {email_address => $invite};
                        $self->hub->user_settings->invite_one_user($proto, '');
                    };
                    if (my $e = $@) {
                        if (Exception::Class->caught('Socialtext::Exception::User')) {
                            push @{$bad_users{$e->message}}, $e->user->email_address;
                        }
                        elsif (Exception::Class->caught('Socialtext::Exception::EmailAddress')) {
                            push @{$bad_users{$e->message}}, $e->email_address;

                        }
                        else {
                            die $e;
                        }
                    }
                }


                $self->invite_errors(\%bad_users) if keys %bad_users;
            }

            if (my $blog = $space_settings->{do}{create_blog}) {
                my $tag = $self->hub->weblog->create_weblog($blog);
                $redirect = $self->hub->weblog->weblog_url($tag);
            }

            my $unsubscribe = $space_settings->{do}{unsubscribe};
            if (defined $unsubscribe && $unsubscribe == 1) {
                $self->space->remove_user(user => $self->rest->user);
                $redirect = '/st/settings';
            }
        }

        my $preferences = $self->hub->preferences;
        if (my $prefs = $settings->{prefs}) {
            for my $index (keys %$prefs) {
                $preferences->store(
                    $self->rest->user, $index, $prefs->{$index});
            }
        }
    };
    if (my $e = $@) {
        st_log->error("Could not save settings: $e");
        $self->message(loc('Error when saving settings'));
    }
    else {
        $self->message(loc('Saved'))
            unless $self->invite_errors;
    }

    return $redirect
      ? $self->redirect($redirect)
      : $self->get_space_html($rest);
}

sub _user_has_correct_perms {
    my $self = shift;

    my %abilities = $self->AdminAbilities;
    my $perm = (grep { $_ eq $self->pref } keys %abilities)
        ? ST_ADMIN_WORKSPACE_PERM
        : ST_READ_PERM;

    $perm = ST_EDIT_PERM if $self->pref eq 'blog';

    return $self->space->user_can(
        user => $self->rest->user,
        permission => $perm,
    );
}

around 'GET_space' => \&wrap_get;
sub GET_space { 
    my $self = shift;
    my $rest = shift;

    return $self->error(loc('Not Found')) unless $self->space;
    return $self->error(loc('Not Authorized'))
        unless $self->_user_has_correct_perms;

    return $self->get_space_html($rest);
}

sub get_space_html {
    my $self = shift;
    my $rest = shift;

    my $space = $self->space;
    my $vars = $self->_settings_vars();
    $vars->{section} = 'space';
    $vars->{space} = {
        rest_url => '/data/workspaces/'. $space->name,
        auw_for => $space->is_all_users_workspace
            ? $space->account->name
            : undef,
        users => [ $space->user_roles(direct => 1)->all() ],
        groups => [ $space->group_roles(direct => 1)->all() ],
        domain_restriction => $space->account->restrict_to_domain,
        invitation_filter => $space->invitation_filter,
        require_registered => $space->restrict_invitation_to_search,
    };

    my $content;
    eval {
        $vars->{prefs} = $self->fetch_prefs();
        $vars->{invite_errors} = $self->invite_errors();

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

sub _plugin_prefs_table {
    my $self = shift;
    my $plugin = shift;

    return Socialtext::PrefsTable->new(
        table => 'user_plugin_pref',
        identity => {
            plugin => $plugin,
            user_id => $self->rest->user->user_id,
        },
    );
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
    $vars->{message} = $self->message;

    return $vars;
}

sub _space_prefs {
    my $self = shift;
    my $space = shift;

    my $user = $self->rest->user;
    my $pref = eval { $self->pref };
    my $id = eval { $self->workspace_id };

    my $is_space = $id && $space->workspace_id == $id;
    my $can_admin = $space->user_can(
        user => $user,
        permission => ST_ADMIN_WORKSPACE_PERM,
    );

    my %abilities = (
        preferences => loc('Preferences'),
    );

    $abilities{unsubscribe} = loc('Unsubscribe')
       if $space->has_user($user, direct=>1);

    $abilities{blog} = loc('Create Blog')
        if $space->user_can(
            user => $user,
            permission => ST_EDIT_PERM,
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
        manage => loc('Manage Users'),
        features => loc('Features'),
    );
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
