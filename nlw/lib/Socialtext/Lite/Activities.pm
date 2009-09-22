package Socialtext::Lite::Activities;
# @COPYRIGHT@
use Moose;
use Socialtext::l10n qw(loc);
use Socialtext::Events::Reporter;
use namespace::clean -except => 'meta';

extends 'Socialtext::Lite';

=head1 NAME

Socialtext::Lite::Activities

=head1 SYNOPSIS

call events()

=head1 DESCRIPTION

Fetches types of events for miki signals and activities.

=cut

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
    my $pagenum = $args{pagenum} || 0;

    my %event_args = (
        ($args{event_class} ? (event_class => $args{event_class}) : ()),
        offset => $pagenum * $page_size,
        count => $page_size + 1,
        with_my_signals => 1,
    );
    my $reporter = Socialtext::Events::Reporter->new(
        viewer => $viewer,
        link_dictionary => $self->link_dictionary,
    );

    my ($events, $error, $base_uri);
    if ($args{mine}) {
        $base_uri = "/m/$args{section}?mine=1";
        $events = $reporter->get_events_activities($viewer, \%event_args);
        $error = loc("There are no [_1] to display because you have not created any.", $args{section}) unless @$events;
    }
    elsif ($args{followed}) {
        $base_uri = "/m/$args{section}?followed=1";
        $events = $reporter->get_events_followed(\%event_args);
        $error = loc("There are no [_1] to display, either because you aren't following anyone yet, or the people you're following haven't created any. Visit the profiles of your colleagues, and click 'Follow this person' to start following colleagues.", $args{section}) unless @$events;
    }
    elsif ($args{all}) {
        $base_uri = "/m/$args{section}?all=1";
        if ($args{section} eq 'activities') {
            $event_args{activity} = 'all-combined';
        }

        $events = $reporter->get_events(\%event_args);

        $error = loc("There are no [_1] to display because none have been created.", $args{section}) unless @$events;
    }
    else {
        $base_uri = "/m/$args{section}";
        $events = $reporter->get_events_conversations($viewer, \%event_args);
        $error = loc("There are no [_1] to display because you haven't engaged in conversations with your colleagues.", $args{section}) unless @$events;
    }
    $events ||= [];
    my $more = pop @$events if @$events > 10;

    $self->hub->viewer->link_dictionary($self->link_dictionary);
    return $self->_process_template(
        "lite/$args{section}.html",
        error    => $error,
        events   => $events,
        more     => $more ? 1 : 0,
        base_uri => $base_uri,
        %args,
    );
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
