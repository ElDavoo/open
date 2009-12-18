package Socialtext::Handler::Container;
use Moose::Role;
use Socialtext::HTTP ':codes';
use Socialtext::Workspace;
use Socialtext::l10n qw/loc_lang/;
use Socialtext::JSON qw(encode_json);
use Exception::Class;
use Socialtext::AppConfig;
use Socialtext::Gadgets::Container;
use Socialtext::Gadgets::Util qw(share_path plugin_dir);
use namespace::clean -except => 'meta';

our $prod_ver = Socialtext->product_version;
our $code_base = Socialtext::AppConfig->code_base;

use constant 'entity_name' => 'Container';

requires 'container';

has 'template_paths' => (
    is => 'ro', isa => 'ArrayRef',
    lazy_build => 1,
);
sub _build_template_paths {
    my $ self = shift;
    return [
        @{Socialtext::Gadgets::Util::template_paths()},
        @{$self->hub->skin->template_paths},
    ];
}

sub authorized_to_view {
    my $self = shift;
    return 1
        if $self->rest->user->is_authenticated
        and $self->rest->user->can_use_plugin($self->container->plugin);
}

sub authorized_to_edit {
    my $self = shift;
    return 1
        if $self->rest->user->is_authenticated
        and $self->rest->user->can_use_plugin($self->container->plugin);
}

sub GET {
    my ($self, $rest) = @_;

    loc_lang( $self->hub->best_locale );

    unless ($self->authorized_to_view) {
        $self->rest->header(
            -status => HTTP_302_Found,
            -Location => '/',
        );
        return 'Unauthorized';
    }

    $self->rest->header('Content-Type' => 'text/html; charset=utf-8');
    return $self->get_html;
}

sub get_html {
    my $self = shift;
    return $self->render_template('view/container', {
        container => $self->container->template_vars
    });
}

sub render_template {
    my ($self, $template, $vars) = @_;
    my $renderer = Socialtext::TT2::Renderer->instance;
    return $renderer->render(
        template => $template,
        paths => $self->template_paths,
        vars => {
            %{$self->template_vars},
            %$vars,
        },
    );
}

sub template_vars {
    my $self = shift;
    my %global_vars = $self->hub->helpers->global_template_vars;
    return {
        #target => $target,
        share => share_path,
        workspaces => [$self->hub->current_user->workspaces->all],
        as_json => sub {
            my $json = encode_json(@_);

            # hack so that json can be included in other <script> 
            # sections without breaking stuff
            $json =~ s!</script>!</scr" + "ipt>!g;

            return $json;
        },
        %global_vars,
    };
}

1;
