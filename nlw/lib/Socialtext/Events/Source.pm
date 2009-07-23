package Socialtext::Events::Source;
# @COPYRIGHT@
use Moose::Role;
use Socialtext::Events::FilterParams;
use namespace::clean -except => 'meta';

has 'viewer' => (
    is => 'ro', isa => 'Socialtext::User', required => 1,
    handles => {
        viewer_id => 'user_id',
    },
);

has 'user' => (
    is => 'ro', isa => 'Socialtext::User', required => 1,
    lazy => 1,
    default => sub { shift->viewer },
    handles => {
        user_id => 'user_id',
    },
);

has 'limit' => ( is => 'ro', isa => 'Int', default => 50 );

has 'filter' => (
    is => 'ro', isa => 'Socialtext::Events::FilterParams',
    handles => [qw(before after)],
);

requires 'prepare'; # returns false if no results
requires 'peek';
requires 'next';
requires 'skip';

sub all {
    my $self = shift;
    my @events;
    $#events = $self->limit - 1; $#events = -1; # preallocate space
    while (my $e = $self->next) {
        push @events, $e;
    }
    return @events if wantarray;
    return \@events;
}

sub all_hashes {
    my $self = shift;
    my @hashes;
    $#hashes = $self->limit - 1; $#hashes = -1; # preallocate space
    while (my $e = $self->next) {
        push @hashes, $e->build_hash({});
    }
    return @hashes if wantarray;
    return \@hashes;
}

package Socialtext::Events::EmptySource;
use Moose;
with 'Socialtext::Events::Source';

sub prepare { undef }
sub peek    { undef }
sub next    { undef }
sub skip    { undef }

1;

__END__

=head1 NAME

Socialtext::Events::Source - Base role for all Sources.

=head1 DESCRIPTION

Defines the Iterator interface for all concrete Source implementations.

The iterator returns a sequence of events in descending time order (newest to
oldest).  Failure to do so will break any Stream this Source is composed into.

=head1 SYNOPSIS

A real implementation would do something interesting with the required methods.

    package EmptySource;
    use Moose;
    with 'Socialtext::Events::Source';

    sub prepare { undef }
    sub peek    { undef }
    sub next    { undef }
    sub skip    { undef }

    package MyApp;

    my $src = Socialtext::Events::MySource->new(
        filter => Socialtext::Events::FilterParams->new( ... ),
        limit => 25
    );
    print "no events" unless $src->prepare();
    my $evs = $src->all();

    # OR
    while (my $e = $src->next()) {
        print Dumper($e->to_hash);
    }

    # OR (Streams do something like this to merge sources)
    while ($src->peek()) {
        my $e = $src->next(); # potentially not called for all events
        print Dumper($e->to_hash);
    }

=head1 METHODS

=over 4
 
=item prepare

Do whatever query to collect your events.

    my $has_events = $src->prepare();

Do the minimum amount of work to determine if events are available.  Don't
instantiate objects or do any expensive per-event calculations until C<next()>
is called.

=item peek

Return the epoch time of the next event without instantiating that object.
The goal is that this method is called when composing Sources together into a
Stream, so calling C<peek()> B<must> be as light-weight as possible.

Returns undef if there are no more events.

C<peek()> must not move ahead in the sequence of events.  Generally, C<peek()>
is called immediately before C<next()>, but don't rely on it.

    my $epoch_at = $src->peek(); # floating-point epoch is best

=item skip

Skip over the next event without instantiating it. This allows us to implement
offsets in our Streams.

    $src->skip();

=item next

Return the next C<Socialtext::Events::Event> or undef if there are no more
events.

    my $event = $src->next();

=back

=head1 SEE ALSO

C<Socialtext::Events::Stream> - how Sources are composed together.
