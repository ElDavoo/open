package Socialtext::Handler::Authen;
# @COPYRIGHT@
use strict;
use warnings;

use base 'Socialtext::Handler';

use Apache::Constants qw( NOT_FOUND );
use Socialtext;

use Encode ();
use Email::Valid;
use Exception::Class;
use Socialtext::AppConfig;
use Socialtext::Authen;
use Socialtext::BrowserDetect;
use Socialtext::Hub;
use Socialtext::Log qw(st_log st_timed_log);
use Socialtext::Timer;
use Socialtext::Apache::User;
use Socialtext::User;
use Socialtext::Session;
use Socialtext::Helpers;
use Socialtext::Workspace;
use Socialtext::Permission qw( ST_SELF_JOIN_PERM );
use Socialtext::l10n qw( loc loc_lang system_locale );
use URI::Escape qw(uri_escape_utf8);

sub handler ($$) {
    my $class = shift;
    my $r     = shift;

    my $self = bless {r => $r}, __PACKAGE__; # new can kiss my ass
    $self->{args} = { $r->args, $r->content };

    loc_lang( system_locale() );

    (my $uri = $r->uri) =~ s[^/nlw/?][];
    if ($uri =~ m[submit/]) {
        my ($action) = $uri =~ m[submit/(\w+)];
        
        return $self->$action if $self->can($action);
        warn "Can't handle action '$action'";
        return NOT_FOUND;
    } 
    elsif ($uri =~ /\.html$/) {
        # strip off trailing ; to avoid warning
        (my $query_string = $r->args || '') =~ s/;$//;
        $r->args($query_string);

        # sucks, but we need a Hub to get the global template vars and to
        # get the list of available public workspaces
        my $hub  = $self->_load_hub();
        my $user = $hub->current_user();

        # vars that we're setting up to use in our template later on
        my $vars = {};

        if ($uri eq 'choose_password.html') {
            my $saved_args  = $self->session->saved_args;
            my $hash        = $saved_args->{hash};
            my $account_for = $saved_args->{account_for};

            return $self->_challenge() unless $hash;

            my $user = $self->_find_user_for_email_confirmation_hash( $r, $hash );
            return $self->_challenge() unless $user;

            $vars->{email_address} = $user->email_address;
            $vars->{hash}          = $hash;

            if ($account_for && $account_for eq 'free50') {
                $vars->{title}         = loc("Free50 Account Setup");
                $vars->{heading}       = loc("Free50 Account Setup");
                $vars->{to_create}     = loc("Socialtext Free50 account");
            }
            else {
                $vars->{title}         = loc("Choose Password");
                $vars->{heading}       = loc("Choose Password");
                $vars->{to_create}     = loc("Socialtext account");
            }
        }

        # Include login_message_file content in vars sent to template
        # if login_message_file is set in AppConfig.
        if ( $uri eq 'login.html' ) {
            # URL to the miki login page
            $vars->{miki_url} = '/lite/login';

            # if we're redirecting to a miki page, use the miki login page
            # instead
            my $redirect_to = $self->{args}{redirect_to} || '';
            if ($redirect_to =~ m#^(?:https?://[^/]+)?/lite/#) {
                return $self->_redirect( $vars->{miki_url} );
            }

            # mobile browsers should see the miki login page instead
            if (Socialtext::BrowserDetect::is_mobile()) {
                return $self->_redirect( $vars->{miki_url} );
            }

            # login message
            my $file = Socialtext::AppConfig->login_message_file();
            if ( $file and -r $file ) {
                # trap any errors and ignore them to the error log
                eval {
                    $vars->{login_message}
                        = Socialtext::File::get_contents_utf8($file);
                };
                warn $@ if $@;
            }
        }
        if (($uri eq 'login.html') || ($uri eq 'logout.html')) {
            # list of public workspaces (for Workspace List)
            $vars->{public_workspaces}
                = [ $hub->workspace_list->public_workspaces ];
        }
        if ( $uri eq 'join.html' ) {
            my $redirect_to = $self->{args}{redirect_to} || '';
            if (my $ws_name = $self->{args}{workspace_name}) {
                if ($self->_add_user_to_workspace($user, $ws_name)) {
                    return $self->_redirect($redirect_to);
                }
            }
        }

        if ($self->{args}{workspace_name}) {
            $vars->{target_workspace} = Socialtext::Workspace->new(name => $self->{args}{workspace_name});
        }
        my @errors;
        if ($r->prev) {
            @errors = split /\n/, $r->prev->pnotes('error') || '';
        }
        if ($uri eq 'errors/500.html') {
            return $class->handle_error( $r, \@errors);
        }

        my $saved_args = $self->{saved_args} = $self->session->saved_args;
        my $repl_vars  = {
            $self->_default_template_vars(),
            authen_page    => 1,
            username_label => Socialtext::Authen->username_label,
            redirect_to    => $self->{args}{redirect_to},
            %$saved_args,
            %$vars,
        };
        return $class->render_template($r, "authen/$uri", $repl_vars);
    }

    warn "Unknown URI: $uri";
    return NOT_FOUND;
}

sub login {
    my ($self) = @_;
    my $r = $self->r;

    # depending on whether this is the "real" or "lite" version of the login,
    # we'll want to redirect them to an appropriate login page.
    my $login_uri = $self->{args}{lite} ? '/lite/login' : '/nlw/login.html';

    my $validname = ( Socialtext::Authen->username_is_email()
        ? 'email address'
        : 'username'
    );
    my $username = $self->{args}{username} || '';
    unless ($username) {
        $self->session->add_error(loc('You must provide a valid [_1].', $validname));
        return $self->_redirect($login_uri);
    }

    my $user_check = ( Socialtext::Authen->username_is_email()
        ? Email::Valid->address($username)
        : ( (Encode::is_utf8($username) ? $username : Encode::decode_utf8($username)) =~ /\w/ )
    );

    unless ( $user_check ) {
        $self->session->add_error( loc('"[_1]" is not a valid [_2]. Please use your [_2] to log in.', $username, $validname) );
        $r->log_error ($username . ' is not a valid ' . $validname);
        return $self->_redirect($login_uri);
    }
    my $auth = Socialtext::Authen->new;
    my $user = Socialtext::User->new( username => $username );

    if ($user && !$user->email_address) {
        $self->session->add_error(loc("This username has no associated email address." ));
        $r->log_error ($username . ' has no associated email address');
        return $self->_redirect($login_uri);
    }

    if ($user and $user->requires_confirmation) {
        $r->log_error($username . ' requires confirmation');
        return $self->require_confirmation_redirect($user->email_address);
    }

    unless ($self->{args}{password}) {
        $self->session->add_error(loc('Wrong [_1] or password - please try again', $validname));
        $r->log_error('Wrong ' . $validname .' or password for ' . $username);
        return $self->_redirect($login_uri);
    }

    my $check_password = $auth->check_password(
        username => ($username || ''),
        password => $self->{args}{password},
    );

    unless ($check_password) {
        $self->session->add_error(loc('Wrong [_1] or password - please try again', $validname));
        $r->log_error('Wrong ' . $validname .' or password for ' . $username);
        return $self->_redirect($login_uri);
    }

    my $expire = $self->{args}{remember} ? '+12M' : '';
    Socialtext::Apache::User::set_login_cookie( $r, $user->user_id, $expire );

    $user->record_login;

    my $dest = $self->{args}{redirect_to};
    unless ($dest) {
        $dest = "/";
    }

    st_timed_log('info', 'WEB', "LOGIN", $user, {}, Socialtext::Timer->Report);

    if (my $ws_name = $self->{args}{workspace_name}) {
# XXX: display error, not using the login template
        $self->_add_user_to_workspace($user, $ws_name)
            or return $self->_redirect($login_uri);
    }

    $self->session->write;
    $self->redirect($dest);
}

# Add a user to a workspace that can "self join". Returns 1 on success.
sub _add_user_to_workspace {
    my ($self, $user, $ws_name) = @_;
    my $ws = Socialtext::Workspace->new( name => $ws_name );
    if ($ws and $user->is_authenticated) {
        if ($ws->has_user($user)) {
            return 1;
        }

        my $perms = $ws->permissions;
        my $can_self_join = $perms->role_can( 
            role => Socialtext::Role->Guest(),
            permission => ST_SELF_JOIN_PERM
        );
        if ($can_self_join) {
            $ws->add_user(
                user => $user, role => Socialtext::Role->Member()
            );
            return 1;
        }
        else {
            $self->session->add_error(
                loc("Self-join is disabled for [_1]", $ws_name)
            );
        }
    }
}

sub logout {
    my $self     = shift;
    my $redirect = $self->{args}{redirect_to}
        || Socialtext::AppConfig->logout_redirect_uri();

    Socialtext::Apache::User::unset_login_cookie();
    $self->redirect($redirect);
}

sub forgot_password {
    my $self = shift;
    my $r = $self->r;

    my $login_uri = $self->{args}{lite} ? '/lite/login' : '/nlw/login.html';
    my $forgot_password_uri = $self->{args}{lite} ? '/lite/forgot_password' : '/nlw/forgot_password.html';

    my $username = $self->{args}{username} || '';
    my $user = Socialtext::User->new( username => $username );
    unless ( $user ) {
        $self->session->add_error(loc("[_1] is not registered as a user. Try a different entry?", $username));
        return $self->_redirect($forgot_password_uri);
    }
    elsif ($user->is_deactivated) {
        $self->session->add_error(loc("The user [_1] has been deactivated.", $username));
        return $self->_redirect($forgot_password_uri);
    }
    elsif ($user->is_externally_sourced) {
        $self->session->add_error(
            loc("Since your password is stored in the directory for your organization, there is no way to reset your password within the Socialtext system. Please contact your directory administrator for assistance.")
        );
        return $self->_redirect($forgot_password_uri);
    }

    $user->set_confirmation_info( is_password_change => 1 );
    $user->send_password_change_email();

    $self->session->add_message( 
        loc('An email with instructions on changing your password has been sent to [_1].', $user->username)
    );

    $self->session->save_args( username => $user->username() );

    $self->_redirect($login_uri);
}

sub register {
    my $self = shift;
    my $r = $self->r;

    my $target_ws_name  = $self->{args}{workspace_name};
    my $redirect_target = $target_ws_name
        ? "/nlw/join.html?workspace_name=$target_ws_name"
        : '/nlw/register.html';

    unless (Socialtext::AppConfig->self_registration()) {
        $self->session->add_error(loc("Registration is disabled."));
        return $self->_redirect($redirect_target);
    }

    my $ws;
    if ($target_ws_name) {
        eval {
            $ws = Socialtext::Workspace->new( name => $target_ws_name);
            my $perms = $ws->permissions;
            if (!$perms->role_can( 
                    role => Socialtext::Role->Guest(),
                    permission => ST_SELF_JOIN_PERM
                )) {
                    $self->session->add_error(loc("Self-join is disabled for")." ".$target_ws_name);
                    return $self->_redirect($redirect_target);
                }
            };
        die $@ if $@;
    }

    my $email_address = $self->{args}{email_address};
    unless ( $email_address ) {
        $self->session->add_error(loc("Please enter an email address."));
        return $self->_redirect($redirect_target);
    }

    my $user = Socialtext::User->new( email_address => $email_address );
    if ($user) {
        if ( $user->requires_confirmation() ) {
            return $self->require_confirmation_redirect($email_address);
        }
        elsif ( $user->has_valid_password() ) {
            $self->session->add_message(loc("A user with this email address ([_1]) already exists.", $email_address));
            $self->session->save_args( email_address => $email_address );

            return $self->_redirect($redirect_target);
        }
    }

    my %args;
    for (qw(password password2 first_name last_name)) {
        $args{$_} = $self->{args}{$_} || '';
    }
    if ( $args{password} and $args{password} ne $args{password2} ) {
        $self->session->add_error(loc('The passwords you provided did not match.'));
    }

    my $is_new_user;
    eval {
        if ($user) {
            $user->update_store(
                password   => $args{password},
                first_name => $args{first_name},
                last_name  => $args{last_name},
            );
        }
        else {
            $user = Socialtext::User->create(
                username      => $email_address,
                email_address => $email_address,
                password      => $args{password},
                first_name    => $args{first_name},
                last_name     => $args{last_name},
            );
            $is_new_user = 1;
        }
    } unless $self->session->has_errors;
    if ( my $e = Exception::Class->caught('Socialtext::Exception::DataValidation') ) {
        # We don't show them "Username is required" since that field
        # is not on the form.
        $self->session->add_error($_) for grep { ! /Username.+required/i } $e->messages;
    }
    elsif ( $@ ) {
        die $@;
    }

    if ( $self->session->has_errors ) {
        my $redirect = delete $self->{args}{redirect_to};
        $self->session->save_args( %{ $self->{args} } );
        return $self->_redirect($redirect_target);
    }


    $user->set_confirmation_info(workspace_name => $target_ws_name);
    $user->send_confirmation_email;

    $self->session->add_message(loc("An email confirming your registration has been sent to [_1].", $email_address));
    return $self->_challenge();
}

sub confirm_email {
    my $self = shift;
    my $r = $self->r;

    my $hash = $self->{args}{hash};
    return $self->_challenge() unless $hash;

    my $user = $self->_find_user_for_email_confirmation_hash( $r, $hash );
    return $self->_challenge() unless $user;

    if ( $user->confirmation_has_expired ) {
        $user->set_confirmation_info();

        if ( $user->confirmation_is_for_password_change() ) {
            $user->send_password_change_email();
        }
        else {
            $user->send_confirmation_email();
        }

        $self->session->add_error(loc("The confirmation URL you used has expired. A new one will be sent."));
        return $self->_challenge();
    }

    if ( $user->confirmation_is_for_password_change or not $user->has_valid_password ) {
        $self->session->save_args(
            hash => $hash,
            ($self->{args}{account_for} 
                ? (account_for => $self->{args}{account_for}) : ()),
        );
        return $self->_redirect( "/nlw/choose_password.html" );
    }

    # Need to grab wsid before we do confirm_email_address, cuz that wipes the
    # email_confirmation
    my $wsid = $user->confirmation_workspace_id;

    $user->confirm_email_address();

    my $targetws;
    if ( $wsid ) {
        $targetws = Socialtext::Workspace->new(workspace_id => $wsid);
        $targetws->add_user(user => $user);
        my $set_account;
        $user->primary_account($targetws->account);
        st_log->info("SELF_JOIN,user:". $user->email_address . "("
            .$user->user_id."),workspace:"
            . $targetws->name . "(" . $targetws->workspace_id . ")"
            . ",".$targetws->account->name 
            . "(". $targetws->account->account_id . ")" 
        );
    }
    my $address = $user->email_address;
    if ($targetws) {
        $self->session->add_message(loc("Your email address, [_1], has been confirmed and you have been added to the [_2] workspace. Please login.", $address, $targetws->title));
    }
    else {
        $self->session->add_message(loc("Your email address, [_1], has been confirmed. Please login.", $address));
    }
    $self->session->save_args( username => $user->username );

    $self->{args}{redirect_to} = $targetws->uri if ($targetws);
    return $self->_challenge();
}

sub choose_password {
    my $self = shift;
    my $r = $self->r;

    my $hash = $self->{args}{hash};
    return $self->_challenge unless $hash;

    my $user = $self->_find_user_for_email_confirmation_hash( $r, $hash );
    return $self->_challenge unless $user;

    my %args;
    $args{$_} = $self->{args}{$_} || '' for (qw(password password2));
    if ( $args{password} and $args{password} ne $args{password2} ) {
        $self->session->add_error(loc('The passwords you provided did not match.'));
    }
    eval { $user->update_store( password   => $args{password} ) };
    if ( my $e = Exception::Class->caught('Socialtext::Exception::DataValidation') ) {
        # We don't show them "Username is required" since that field
        # is not on the form.
        $self->session->add_error($_) for grep { ! /Username.+required/i } $e->messages;
    }

    if ( $self->session->has_errors ) {
        return $self->_redirect("/nlw/choose_password.html?hash=$hash");
    }

    my $expire = $self->{args}{remember} ? '+12M' : '';
    Socialtext::Apache::User::set_login_cookie( $r, $user->user_id, $expire );

    $user->confirm_email_address;
    $user->record_login;

    my $dest = $self->{args}{redirect_to};
    unless ($dest) {
        $dest = "/";
    }

    st_log->info( "LOGIN: " . $user->email_address . " destination: $dest" );

    $self->session->remove('account_for');
    $self->session->write;
    $self->redirect($dest);
}

sub resend_confirmation {
    my $self = shift;

    my $email_address = $self->{args}{email_address};
    unless ($email_address) {
        warn "No email address found to resend confirmation";
        return $self->_challenge();
    }

    my $user = Socialtext::User->new( email_address => $email_address );
    unless ($user) {
        $self->session->add_error(loc("[_1] is not registered as a user. Try a different email address?", $email_address));
        return $self->_challenge();
    }

    unless ($user->requires_confirmation) {
        $self->session->add_error(loc("The email address for [_1] has already been confirmed.", $email_address));
        return $self->_challenge();
    }

    $user->set_confirmation_info;
    $user->send_confirmation_email;

    $self->session->add_error(loc('The confirmation email has been resent. Please follow the link in this email to activate your account.'));
    return $self->_challenge();
}

sub require_confirmation_redirect {
    my $self          = shift;
    my $email_address = shift;

    $self->session->save_args( username => $email_address );
    $self->session->add_error( {
        type => 'requires_confirmation',
        args => {
           email_address => $email_address,
           redirect_to   => $self->{args}{redirect_to} || '',
       },
    } );

    return $self->_challenge();
}

sub _redirect {
    my $self = shift;
    my $uri  = shift;
    my $redirect_to = $self->{args}{redirect_to};

    if ($redirect_to) {
        $uri .= ($uri =~ m/\?/ ? ';' : '?')
              . "redirect_to=" . uri_escape_utf8($redirect_to);
    }
    $self->redirect($uri);
}

sub _challenge {
    my $self = shift;
    my $redirect_to   = $self->{args}{redirect_to};
    my $challenge_uri = '/challenge';
    $challenge_uri .= '?' . uri_escape_utf8($redirect_to) if ($redirect_to);
    return $self->_redirect($challenge_uri);
}

sub _load_main {
    my $self = shift;
    my $user = $self->authenticate($self->{r}) || Socialtext::User->Guest();
    my $ws   = Socialtext::NoWorkspace->new();
    my $main = Socialtext->new();
    $main->load_hub(
        current_user      => $user,
        current_workspace => $ws,
    );
    $main->hub->registry->load();
    return $main;
}

sub _load_hub {
    my $self = shift;
    my $main = $self->_load_main();
    return $main->hub();
}

sub _default_template_vars {
    my $self = shift;
    my $hub  = $self->_load_hub();
    return (
        $hub->helpers->global_template_vars,
        loc            => \&loc,
        errors         => [ $self->session->errors ],
        messages       => [ $self->session->messages ],
        static_path    => Socialtext::Helpers::static_path(),
        skin_uri       => sub {
            Socialtext::Skin->new(name => shift)->skin_uri
        },
        paths          => $hub->skin->template_paths,
        st_version     => $Socialtext::VERSION,
        support_address => Socialtext::AppConfig->support_address,
    );
}

sub _find_user_for_email_confirmation_hash {
    my $self = shift;
    my $r = shift;
    my $hash = shift;

    # now in order to deal with email clients that might have decoded %2B to '+' for us
    # we need to change spaces in the hash back to '+' signs.
    # see: https://rt.socialtext.net:444/Ticket/Display.html?id=26571
    $hash =~ s/ /+/g;

    my $user = Socialtext::User->new( email_confirmation_hash => $hash );
    unless ($user) {
        $self->session->add_error(loc("The given confirmation URL does not match any pending confirmations."));
        $self->session->add_error( "<br/>(" . $r->uri . "?" . $r->args . ")" );
        $r->log_error ("no confirmation hash for: [" . $r->uri . "?" . $r->args . "]" );
    }
    return $user;
}

1;

__END__
Actions:
    check: login
    check: logout
    check: forgot_password
    check: register
    resend_confirmation
    check: confirm_email
    choose_password
