package Socialtext::Handler::Container;
use Moose::Role;
use Socialtext::HTTP ':codes';
use Socialtext::Workspace;
use Socialtext::l10n qw/loc_lang/;
use Socialtext::JSON qw(encode_json);
use Exception::Class;
use Socialtext::AppConfig;
use Socialtext::Gadgets::Container;
use Socialtext::Gadgets::Util qw(share_path plugin_dir template_paths);
use namespace::clean -except => 'meta';

our $prod_ver = Socialtext->product_version;
our $code_base = Socialtext::AppConfig->code_base;

use constant 'entity_name' => 'Container';

requires 'container';

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

    # XXX:
    #my $target;
    if ($self->rest->query->{target_id}) {
        die 'XXX: Implement this'
    #    my $target_container = $self->container(id => $cgi_vars{target_id});
    #    $target = $target_container->template_vars;
    }

    $self->rest->header('Content-Type' => 'text/html; charset=utf-8');

    my $renderer = Socialtext::TT2::Renderer->instance;
    my $template_paths = template_paths;
    return $renderer->render(
        template => "view/container",
        paths => [ @{$self->hub->skin->template_paths}, @$template_paths ],
        vars => $self->template_vars,
    );
}

sub template_vars {
    my $self = shift;
    my %template_vars = $self->hub->helpers->global_template_vars;
    return {
        viewer => $self->rest->user->username,
        container => $self->container->template_vars,
        #target => $target,
        pref_list => sub {
            $self->_get_pref_list;
        },
        share => share_path,
        workspaces => [$self->hub->current_user->workspaces->all],
        as_json => sub {
            my $json = encode_json(@_);

            # hack so that json can be included in other <script> 
            # sections without breaking stuff
            $json =~ s!</script>!</scr" + "ipt>!g;

            return $json;
        },
        %template_vars,
        $self->{_action_plugin} ?
            (action_plugin => $self->{_action_plugin}) : (),
    };
}

sub _get_pref_list {
    my $self = shift;
    my $prefs = $self->hub->preferences_object->objects_by_class;
    my @pref_list = map {
        $_->{title} =~ s/ /&nbsp;/g;
        $_;
        } grep { $prefs->{ $_->{id} } }
        grep { $_->{id} ne 'search' } # hide search prefs screen
        @{ $self->hub->registry->lookup->plugins };
    return \@pref_list;
}

1;
