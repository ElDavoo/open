package Socialtext::Handler::Gadget;
# @COPYRIGHT@
use Moose::Role;
use Socialtext::JSON qw(encode_json decode_json);
use Socialtext::HTTP qw(:codes);
use namespace::clean -except => 'meta';

requires qw(container if_authorized_to_edit if_authorized_to_view);

sub ws {}

has 'gadget' => (
    is => 'ro', isa => 'Maybe[Socialtext::Gadgets::GadgetInstance]',
    lazy_build => 1,
);

sub _build_gadget {
    my $self = shift;
    return $self->container->get_gadget_instance($self->gadget_instance_id);
}

around 'if_authorized_to_view' => sub {
    my ($orig, $self, $cb) = @_;
    return $self->not_found unless $self->gadget;
    return $orig->($self, $cb);
};

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

sub GET_html {
    my $self = shift;
    $self->if_authorized_to_view(sub {
        # Override any preferences from up_ cgi parameters
        my %prefs;
        for my $param ($self->rest->query->param) {
            if ($param =~ /^up_(.*)$/) {
                $prefs{$1} = Encode::decode_utf8(
                    $self->rest->query->param($param)
                );
            }
        }
        $self->gadget->preference_hash(\%prefs);

        $self->rest->header(-type => 'text/html; charset=utf-8');
        return $self->gadget->expanded_content;
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
        for ($cgi->param) {
            if (/^up_(.*)$/) {
                $self->gadget->set_preference($1, $cgi->param($_));
            }
            elsif (/^env_(.*)$/) {
                $self->gadget->set_env($1, $cgi->param($_));
            }
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

__END__

=head1 NAME

Socialtext::Handler::Gadget - role for all gadgets

=head1 SYNOPSIS

  package Socialtext::Handler::Gadget::Dashboard;
  extends 'Socialtext::Handler::Container::Dashboard';
  with 'Socialtext::Handler::Gadget';

=head1 DESCRIPTION

Handles the normal handler stuff for container gadgets.

=cut
