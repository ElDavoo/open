package Socialtext::Handler::Container;
# @COPYRIGHT@
use Moose::Role;
use Socialtext::Workspace;
use Socialtext::JSON qw(encode_json decode_json);
use Exception::Class;
use Socialtext::AppConfig;
use Socialtext::Gadgets::Container;
use Socialtext::Gadgets::Util qw(share_path);
use namespace::clean -except => 'meta';

our $prod_ver = Socialtext->product_version;
our $code_base = Socialtext::AppConfig->code_base;

use constant 'entity_name' => 'Container';

with 'Socialtext::Handler::Base';
requires '_build_container';

has 'container' => (
    is => 'ro', isa => 'Maybe[Socialtext::Gadgets::Container]',
    lazy_build => 1,
);

sub DELETE {
    my $self = shift;
    $self->if_authorized_to_edit(sub {
        $self->container->delete;
        return '';
    });
}

sub if_authorized_to_view {
    my ($self, $cb) = @_;
    return $self->not_authenticated unless $self->rest->user->is_authenticated;
    return $self->not_found unless $self->container;
    return $self->forbidden
        unless $self->rest->user->can_use_plugin($self->container->plugin);
    return $cb->();
}

sub if_authorized_to_edit {
    my ($self, $cb) = @_;
    return $self->if_authorized_to_view($cb);
}


sub get_html {
    my $self = shift;
    $self->if_authorized_to_view(sub {
        my $query = $self->rest->query;
        if ($query->param('add_widget')) {
            $self->if_authorized_to_edit(sub {
                return $self->install_gadget;
            });
        }
        elsif ($query->param('clear')) {
            $self->if_authorized_to_edit(sub {
                $self->container->delete_gadgets;
                return $self->redirect($self->uri);
            });
        }
        elsif ($query->param('reset')) {
            $self->if_authorized_to_edit(sub {
                $self->container->delete;
                return $self->redirect($self->uri);
            });
        }
        else {
            $self->unless_authen_needs_renewal(sub {
                return $self->render_template($self->container->view_template, {
                    container => $self->container->template_vars
                });
            } );
        }
    });
}

sub install_gadget {
    my $self = shift;
    my %params =$self->rest->query->Vars;
    $self->if_authorized_to_edit(sub {
        $self->container->install_gadget(%params);
        return $self->redirect($self->uri);
    });
}

sub PUT_layout {
    my $self = shift;
    $self->if_authorized_to_edit(sub {
        my %gadgets = map { $_->gadget_instance_id => 1 }
                      @{$self->container->gadgets};

        my $layout = decode_json($self->rest->getContent);
        my $business_admin = $self->rest->user->is_business_admin;
        my @positions;
        for my $x (0 .. $#$layout) {
            my $col = $layout->[$x];
            for my $y (0 .. $#$col) {
                my $g = $col->[$y];
                die "Widget $g->{id} is not in container\n"
                    unless $gadgets{$g->{id}};
                my $gadget = $self->container->get_gadget_instance($g->{id});
                push @positions, [$gadget, $x, $y, $g->{minimized}];
            }
        }

        for my $gadget_position (@positions) {
            my $gadget = shift @$gadget_position;
            $gadget->position(@$gadget_position)
        }
    });
}

# Used in wikitests
sub GET_layout {
    my $self = shift;
    my $gadgets = $self->container->gadgets;
    my @cols;
    for (sort { $a->row <=> $b->row } @$gadgets) {
        push @{ $cols[ $_->col ] }, $_->as_hash;
    }
    return encode_json(\@cols);
}

1;

__END__

=head1 NAME

Socialtext::Handler::Container - role for all containers

=head1 SYNOPSIS

  package Socialtext::Handler::Container::Group;
  with 'Socialtext::Handler::Container';

=head1 DESCRIPTION

Handles the normal handler stuff for containers.

=cut
