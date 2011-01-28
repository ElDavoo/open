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

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(wafl => widget => 'Socialtext::WidgetPlugin::Wafl');
}

################################################################################
package Socialtext::WidgetPlugin::Wafl;

use base 'Socialtext::Formatter::WaflPhraseDiv';
use Class::Field qw( const );
use Socialtext::Formatter::Phrase ();

const wafl_id => 'widget';
const wafl_reference_parse => qr/^\s*([^\s#]+)(?:\s*#\s*(\d+))?\s*$/;

sub html {
    my $self = shift;
    my ($widget, $serial) = $self->arguments =~ $self->wafl_reference_parse;

    $serial ||= 1;
    $widget = "local:widgets:$widget" unless $widget =~ /:/;

    my $page_id = $self->current_page_id;
    my $container = Socialtext::Gadgets::Container::Wafl->Fetch(
        owner => $self->hub->current_workspace, 
        viewer => $self->hub->current_user,
        name => "$widget##$page_id#$serial",
    );

    return $self->hub->template->process($container->view_template,
        pluggable => $self->hub->pluggable,
        container => $container->template_vars,
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
    $src =~ s{(.*)##.*}{$1};
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
            src => $self->src,
            col => 0, fixed => 1,
        },
    );
}

1;
__END__

=head1 NAME

Socialtext::WidgetPlugin - Plugin for embedding OpenSocial widgets in wiki pages.

=head1 SYNOPSIS

{widget: tag_cloud}

=head1 DESCRIPTION

Embed OpenSocial widgets into wiki pages.

=cut
