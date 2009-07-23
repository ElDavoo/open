package Socialtext::Events::Source::FromDB;
# @COPYRIGHT@
use Moose::Role;
use MooseX::AttributeHelpers;
use Socialtext::SQL qw/:exec/;
use namespace::clean -except => 'meta';

has 'sql_results' => (
    is => 'rw', isa => 'ArrayRef[HashRef]',
    metaclass => 'Collection::Array',
    lazy_build => 1,
    provides => {
        'first' => 'peek_sql_result',
        'shift' => 'next_sql_result',
    },
);

sub next {
    my $self = shift;
    my $res = $self->next_sql_result || return;
    my $e = $self->event_type->new($res);
    $e->source($self);
    return $e;
}
requires 'event_type';
requires 'query_and_binds';

sub _build_sql_results {
    my $self = shift;
    my ($sql, $binds) = $self->query_and_binds();
    my $sth = sql_execute($sql, @$binds);
    return [] unless $sth->rows > 0;
    return $sth->fetchall_arrayref({});
}

sub prepare {
    my $r = shift->sql_results; # force builder
    return @$r > 0;
}

sub peek {
    my $self = shift;
    my $first = $self->peek_sql_result;
    return unless $first;
    return $first->{at_epoch};
}

sub skip {
    shift->next_sql_result;
    return;
}

sub columns {
    return 'at, EXTRACT(epoch FROM at) AS at_epoch, '.
        'action, actor_id, tag_name, context';
}

sub followed_clause {
    return q{IN (SELECT person_id2
                 FROM person_watched_people__person
                 WHERE person_id1=?)};
}

1;

__END__

=head1 NAME

Socialtext::Events::Source::FromDB - Source role to ease extracting events
from the socialtext DB.

=head1 DESCRIPTION

Satisfies the interface requirements of a C<Socialtext::Events::Source>, but
requires that you implement C<event_class()> and C<query_and_binds()>.

You can only source a single Event type using this role.  If you need more
than one type, you should perhaps implement a Stream instead.

The C<columns> method returns SQL for the columns in a SELECT statement.
Implementers should use C<around()> to append to this string in order to
provide parameters to the Event objects.

The query returned from C<query_and_binds()> will be excecuted and Event
classes created as necessary (i.e. only during C<next()> and not during
C<skip()> or C<peek()>).

=head1 SYNOPSIS

To implement:

    package MySource;
    use Moose;
    use Socialtext::SQL::Builder qw/sql_abstract/;
    with 'Socialtext::Events::Source',
         'Socialtext::Events::Source::FromDB';

    use constant event_class => 'MyFooEvent';
    around 'columns' => sub {
        my $code = shift;
        my $self = shift;
        return $self->$code() . ', foo_id';
    };

    sub query_and_binds {
        my $self = shift;
        my @where = $self->filter->generate_standard_filter();
        ... push other criteria on to @where
        return sql_abstract()->select(
            'foo_event', $self->columns, \@where, 'at DESC', $self->limit
        );
    }

    package MyFooEvent;
    use Moose;
    extends 'Socialtext::Events::Event';
    ...
    has 'foo_id' => ( ..., required => 1 );
    ...

=head1 TODO

Once Moose supports parametric roles, it would be cool to introspect the Event class we're being asked to produce for the applicable columns.
