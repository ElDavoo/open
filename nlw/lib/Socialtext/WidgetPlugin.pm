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
const wafl_reference_parse => qr/^\s*([^\s#]+)(?:\s*#\s*(\d+))?\s*$/

sub html {
    my $self = shift;
    my ($widget, $serial) = $self->arguments =~ $self->wafl_reference_parse;

    $serial ||= 1;
    $widget = "local:widget:$widget" unless $widget =~ /:/;

    my $container = Socialtext::Gadgets::Container::Wafl->Fetch(
        owner => $self->hub->current_workspace, 
        viewer => $self->hub->current_user,
        name => "$widget#$serial",
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
