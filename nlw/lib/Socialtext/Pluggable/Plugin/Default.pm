package Socialtext::Pluggable::Plugin::Default;
# @COPYRIGHT@
use strict;
use warnings;
use Socialtext::BrowserDetect;
use Socialtext::Workspace;

use base 'Socialtext::Pluggable::Plugin';
use Class::Field qw(const field);

sub scope { 'always' }

sub register {
    my $class = shift;
    $class->add_hook('root' => 'root');

    # Priority 99 indicates these hooks should be loaded last.

    # Socialtext People Hooks
    $class->add_hook(
        'template.user_avatar.content' => 'user_name',
        priority                       => 99,
    );
    $class->add_hook(
        'template.user_href.content' => 'user_href',
        priority                     => 99,
    );
    $class->add_hook(
        'template.user_name.content' => 'user_name',
        priority                     => 99,
    );
    $class->add_hook(
        'template.user_small_photo.content' => 'user_photo',
        priority                            => 99,
    );
    $class->add_hook(
        'template.user_photo.content' => 'user_photo',
        priority                      => 99,
    );
    $class->add_hook(
        'wafl.user' => 'user_name',
        priority    => 99,
    );

    $class->add_content_type('wiki', 'Page');
}

sub root {
    my ($self, $rest) = @_;
    my $is_mobile  = Socialtext::BrowserDetect::is_mobile();
    my $default_ws = Socialtext::Workspace->Default();

    if ($default_ws) {
        return $self->redirect('/' . $default_ws->name);
    }

    # logged in users go to the Workspace List
    my $user = $rest->user();
    if ($user and not $user->is_guest) {
        my $redirect_to;
        if ( $self->signals_only ) {
            $redirect_to = '/?signals';
        }
        else {
            $redirect_to = $is_mobile
                ? '/lite/workspace_list'
                : 'action=workspace_list';
        }
        return $self->redirect( $redirect_to );
    }

    return $self->redirect_to_login;
}

sub signals_only {
    my $self = shift;
    return $self->hub->helpers->signals_only;
}

sub user_name {
    my ($self, $username) = @_;
    return $self->best_full_name($username);
}

sub user_href { '' }
sub user_photo { '' }

1;
