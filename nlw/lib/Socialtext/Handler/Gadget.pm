package Socialtext::Handler::Gadget;
# @COPYRIGHT@
use Moose::Role;
use namespace::clean -except => 'meta';

requires 'container';

has 'gadget' => (
    is => 'ro', isa => 'Maybe[Socialtext::Gadgets::GadgetInstance]',
    lazy_build => 1,
);

sub _build_gadget {
    my $self = shift;
    return $self->container->get_gadget_instance($self->gadget_instance_id);
}

sub GET_json {
    my $self = shift;
    $self->if_authorized_to_view(sub {
        $self->rest->header(-type => 'application/json');
        return encode_json({
            content => $self->gadget->content,
            %{$self->gadget->template_vars},
        });
    });
}

sub DELETE {
    my $self = shift;
    $self->if_authorized_to_edit(sub {
        $self->_log_gadget_metadata;
        $self->gadget->delete;
    });
}

sub GET_prefs {
    my $self = shift;
    $self->if_authorized_to_view(sub {
        return encode_json($self->gadget->preference_hash);
    });
}

sub PUT {
    my $self = shift;
    $self->if_authorized_to_edit(sub {
        my $data = decode_json($self->rest->getContent);
        if (exists $data->{fixed}) {
            my $fix = $data->{fixed};
            if ($fix) {
                $self->gadget->fix;
            }
            else {
                $self->gadget->unfix;
            }
        }
        else {
            die "fixed is a required parameter";
        }
        return "success";
    });
}

sub PUT_prefs {
    my $self = shift;
    $self->if_authorized_to_edit(sub {
        use Socialtext::CGI::Scrubbed;
        my $cgi = Socialtext::CGI::Scrubbed->new($self->rest->getContent);
        for my $key (grep { s/^up_// } $cgi->param) {
            $self->gadget->set_preference($key, $cgi->param("up_$key"));
        }

        $self->_log_gadget_metadata;
        return $self->gadget->full_href;
    });
}

sub _log_gadget_metadata {
    my $self = shift;
    $self->rest->meta({
        gadget_id => $self->gadget->gadget_id,
        gadget_title => $self->gadget->title,
    });
}

1;
