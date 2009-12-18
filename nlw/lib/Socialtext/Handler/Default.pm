package Socialtext::Handler::Default;
use Moose;
use Socialtext;
use Socialtext::BrowserDetect;
use Socialtext::Workspace;
use Socialtext::HTTP qw(:codes);
use URI::Escape qw(uri_escape);
use namespace::clean -except => 'meta';

use constant type => 'default';

extends 'Socialtext::Rest::Entity';

sub handler {
    my ($self, $rest) = @_;

    my $is_mobile  = Socialtext::BrowserDetect::is_mobile();
    my $default_ws = Socialtext::Workspace->Default();

    if ($default_ws) {
        return $self->redirect('/' . $default_ws->name);
    }

    return $self->redirect_to_login unless $rest->user->is_authenticated;

    if (my $action = $rest->query->param('action')) {
        my $res;
        eval { $res = $self->hub->process };
        if (my $e = $@) {
            my $redirect_class = 'Socialtext::WebApp::Exception::Redirect';
            if (Exception::Class->caught($redirect_class)) {
                 $rest->header(
                     -status => HTTP_302_Found,
                     -Location => $e->message,
                 );
                 return '';
            }
        }
        $rest->header(-type => 'text/html; charset=UTF-8', # default
                      $self->hub->rest->header);
        return $res;
    }
    else {
        my $redirect_to;
        if ($self->hub->helpers->signals_only) {
            $redirect_to = '/st/signals';
        }
        elsif ($rest->user->can_use_plugin('dashboard')) {
            $redirect_to = '/st/dashboard';
        }
        else {
            $redirect_to = $is_mobile
                ? '/lite/workspace_list'
                : 'action=workspace_list';
        }
        return $self->redirect( $redirect_to );
    }
}

sub redirect_to_login {
    my $self = shift;
    my $uri = uri_escape($ENV{REQUEST_URI} || '');

    if (Socialtext::BrowserDetect::is_mobile()) {
        return $self->redirect('/lite/login');
    }
    return $self->redirect("/nlw/login.html?redirect_to=$uri");
}

sub redirect {
    my ($self,$target) = @_;
    unless ($target =~ /^(https?:|\/)/i or $target =~ /\?/) {
        $target = $self->hub->cgi->full_uri . '?' . $target;
    }
    $self->rest->header(
        -status => HTTP_302_Found,
        -Location => $target,
    );
    return;
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
