package Socialtext::WidgetPlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';
use Class::Field qw(const);
use Socialtext::l10n 'loc';
use Socialtext::Formatter::Phrase ();
use Socialtext::String ();
use Socialtext::Paths ();

const class_id    => 'widget';
const class_title => 'WidgetPlugin';
const cgi_class   => 'Socialtext::WidgetPlugin::CGI';

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(action => 'widget_setup_screen');
    $registry->add(wafl => widget => 'Socialtext::WidgetPlugin::Wafl');
}

sub get_container_for_gadget {
    my $self = shift;
    my ($workspace_name, $page_id, $widget, $serial, $encoded_prefs) = @{$_[0]}{
        qw( workspace_name page_id widget serial encoded_prefs )
    };

    return unless $widget and $workspace_name and $page_id;

    $serial ||= 1;
    $encoded_prefs ||= '';
    $widget = "local:widgets:$widget" unless $widget =~ /:/ or $widget =~ /^\d+$/;

    my $ws = Socialtext::Workspace->new( name => $workspace_name ) or return;

    my $container = eval { Socialtext::Gadgets::Container::Wafl->Fetch(
        owner => $ws,
        viewer => $self->hub->current_user,
        name => "$widget##$workspace_name##$page_id##$serial",
    ) } or return;

    my $gadget = $container->gadgets->[0];
    if (!$gadget) {
        $container->delete;
        return;
    }

    my %new_prefs;
    for my $encoded_pref (split /\s+/, $encoded_prefs) {
        $encoded_pref =~ /^([^\s=]+)=(\S*)/ or next;
        $new_prefs{$1} = Socialtext::String::uri_unescape($2);
    }

    for my $pref (@{ $gadget->preferences || [] }) {
        my $val = $new_prefs{$pref->{name}};
        $val = $pref->{default_value} unless defined $val;

        $val = $ws->name if $pref->{datatype} eq 'workspace';
        $val = $ws->account->name if $pref->{datatype} eq 'account';

        no warnings 'uninitialized';
        if ($pref->{value} ne $val) {
            $gadget->set_preference($pref->{name} => $val);
        }
    }

    return($container, $gadget, \%new_prefs);
}

sub widget_setup_screen {
    my $self = shift;
    my ($container, $gadget) = $self->get_container_for_gadget({
        map { $_ => scalar $self->cgi->$_ }
            qw( workspace_name page_id widget serial encoded_prefs )
    }) or return;

    if ($self->cgi->do_delete_container) {
        $container->delete;
        return '{"deleted": 1}';
    }

    my $workspace = $container->owner;
    my $account = $workspace->account;

    return $self->hub->template->process("view/container.setup",
        $self->hub->helpers->global_template_vars,
        current_workspace => {
            label => $workspace->title,
            name => $workspace->name,
            account => $account->name,
            id => $workspace->workspace_id,
        },
        current_account => {
            name => $account->name,
            account_id => $account->account_id,
            plugins => [$account->plugins_enabled],
        },
        pluggable => $self->hub->pluggable,
        container => $container->template_vars,
    );
}

################################################################################
package Socialtext::WidgetPlugin::CGI;

use base 'Socialtext::CGI';
use Socialtext::CGI qw( cgi );

cgi 'workspace_name';
cgi 'page_id';
cgi 'widget';
cgi 'serial';
cgi 'encoded_prefs';
cgi 'do_delete_container';

################################################################################
package Socialtext::WidgetPlugin::Wafl;

use base 'Socialtext::Formatter::WaflPhraseDiv';
use Class::Field qw( const );
use Socialtext::l10n 'loc';
use Socialtext::Formatter::Phrase ();

const wafl_id => 'widget';
const wafl_reference_parse => qr/^\s*([^\s#]+)(?:\s*#(\d+))?((?:\s+[^\s=]+=\S*)*)\s*$/;

sub html {
    my $self = shift;
    my ($widget, $serial, $encoded_prefs) = $self->arguments =~ $self->wafl_reference_parse;
    my ($container, $gadget, $pref) = $self->hub->widget->get_container_for_gadget({
        workspace_name => $self->hub->current_workspace->name,
        page_id => $self->current_page_id,
        widget => $widget,
        serial => $serial,
        encoded_prefs => $encoded_prefs,
    });

    return loc("The settings for this widget have become corrupted. Please remove and re-insert the widget.")
        unless $container and $widget;

    return $self->hub->template->process($container->view_template,
        pluggable => $self->hub->pluggable,
        container => $container->template_vars,
        width     => $pref->{__width__},
    );
}

################################################################################
package Socialtext::Gadgets::Container::Wafl;
use Moose;
use constant 'type'            => 'wafl';
use constant 'links_template'  => '';
use constant 'hello_template'  => '';
use constant 'footer_template' => '';
use constant 'header_template' => '';
use constant 'global'          => 1;
use constant 'title'           => '';
use constant 'plugin'          => "widgets";
use constant 'view_template'   => 'view/container.wafl';

with 'Socialtext::Gadgets::Container';
has '+owner' => ( isa => 'Socialtext::Workspace' );
has 'src' => (
    is => 'ro', isa => 'Str',
    lazy_build => 1,
);
sub _build_src {
    my $self = shift;
    my $src = $self->name;
    $src =~ s{^([^#]*)##.*}{$1};
    return $src;
}

sub JoinSQL {''}

sub _build_env {+{}}

sub _build_columns {[
    { style => 'width: 99%', borderless => 1 },
]}

sub default_gadgets {
    my $self = shift;
    return (
        {
            (($self->src =~ /^\d+$/) ? 'gadget_id' : 'src') => $self->src,
            col => 0, fixed => 1,
        },
    );
}

################################################################################
package Socialtext::Handler::Gadget::Wafl;

# @COPYRIGHT@
use Moose;
use Socialtext;
use Socialtext::JSON qw(decode_json);
use namespace::clean -except => 'meta';

sub _build_container {
    my $self = shift;
    my $cname = $self->params->{cname} or return;
    my ($widget, $ws_name, $page_id, $serial) = split(/##/, $cname);
    return Socialtext::Gadgets::Container::Wafl->Fetch(
        owner => Socialtext::Workspace->new(name => $ws_name),
        viewer => $self->rest->user,
        name => $cname,
    );
}

extends 'Socialtext::Handler::Container::Dashboard';
with 'Socialtext::Handler::Gadget';

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
__END__

=head1 NAME

Socialtext::WidgetPlugin - Plugin for embedding OpenSocial widgets in wiki pages.

=head1 SYNOPSIS

{widget: tag_cloud}

=head1 DESCRIPTION

Embed OpenSocial widgets into wiki pages.

=cut
