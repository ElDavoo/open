package Socialtext::Lite::Activities;
# @COPYRIGHT@
use Moose;
use Socialtext::l10n qw(loc);
use Socialtext::Events::Reporter;
use namespace::clean -except => 'meta';

extends 'Socialtext::Lite';

sub activities {
    my $self = shift;
    return $self->events(
        'action!' => 'view,edit_start,edit_cancel,watch_add,watch_delete',
        title => 'Activities',
        section => 'activities',
        @_,
    );
}

sub events {
    my ($self, %args) = @_;
    my $viewer = $self->hub->current_user;
    my $page_size = 10;

    my %event_args = (
        ($args{event_class} ? (event_class => $args{event_class}) : ()),
        offset => $args{pagenum} * $page_size,
        count => $page_size + 1,
    );
    my $reporter = Socialtext::Events::Reporter->new(viewer => $viewer);

    my $events;
    if ($args{mine}) {
        $events = $reporter->get_events_activities($viewer, \%event_args);
    }
    elsif ($args{followed}) {
        $events = $reporter->get_events_followed(\%event_args);
    }
    elsif ($args{all}) {
        if ($args{section} eq 'activities') {
            $events = $reporter->get_events_activities($viewer, \%event_args);
        }
        else {
            $events = $reporter->get_events(\%event_args);
        }
    }
    else {
        $events = $reporter->get_events_conversations($viewer, \%event_args);
    }
    $events ||= [];

    my $more = pop @$events if @$events > 10;

    $self->hub->viewer->link_dictionary($self->link_dictionary);
    return $self->_process_template(
        "lite/activities.html",
        events   => $events,
        more     => $more ? 1 : 0,
        base_uri => "/m/$args{section}",
        %args,
    );
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
