package Socialtext::User::Find;
# @COPYRIGHT@
use Moose;
use Socialtext::SQL qw/get_dbh sql_execute sql_singlevalue/;
use Socialtext::SQL::Builder qw/sql_abstract/;
use Socialtext::String;
use Socialtext::User;
use namespace::clean -except => 'meta';

has 'viewer' => (is => 'rw', isa => 'Socialtext::User', required => 1);
has 'limit' => (is => 'rw', isa => 'Maybe[Int]');
has 'offset' => (is => 'rw', isa => 'Maybe[Int]');
has 'filter' => (is => 'rw', isa => 'Maybe[Str]');
has 'order' => (is => 'ro', isa => 'Maybe[Str]');
has 'reverse' => (is => 'ro', isa => 'Bool', default => 0);
has 'minimal' => (is => 'ro', isa => 'Bool', default => 0);

sub cleanup_filter {
    my $self = shift;
    my $new_value = shift;

    # undef: everyone
    # empty: invalid query
    # non-empty: prefix match

    return $self->filter('%') unless defined $self->filter;

    my $filter = lc Socialtext::String::trim($self->filter);

    # If we don't get rid of these wildcards, the LIKE operator slows down
    # significantly.  Matching on anything other than a prefix causes Pg to not
    # use the 'text_pattern_ops' indexes we've prepared for this query.
    $filter =~ s/[_%]//g; # remove wildcards

    # Remove start of word character
    $filter =~ s/\\b//g;

    die "empty filter"
        if (defined $filter && $filter =~ /^\s*$/);

    $filter .= '%';

    return $self->filter($filter);
}

has 'sql_from' => (
    is => 'ro', isa => 'Str', lazy_build => 1,
);
sub _build_sql_from {
    return q{
        user_sets_for_user viewer
        JOIN user_sets_for_user other USING (user_set_id)
        JOIN users ON (other.user_id = users.user_id)
    };
}

has 'sql_cols' => (
    is => 'ro', isa => 'ArrayRef', lazy_build => 1,
);
sub _build_sql_cols {
    return [
        'DISTINCT users.user_id', 'first_name', 'last_name',
        'email_address', 'driver_username',
    ];
}

has 'sql_count' => (
    is => 'ro', isa => 'ArrayRef', lazy_build => 1,
);
sub _build_sql_count {
    return ['COUNT(DISTINCT(users.user_id))'];
}

has 'sql_where' => (
    is => 'ro', isa => 'HashRef', lazy_build => 1,
);
sub _build_sql_where {
    my $self = shift;
    my $filter = $self->filter;
    return {
        '-and' => [ 'viewer.user_id' => $self->viewer->user_id ],
        '-or' => [
            'lower(first_name)'      => { '-like' => $filter },
            'lower(last_name)'       => { '-like' => $filter },
            'lower(email_address)'   => { '-like' => $filter },
            'lower(driver_username)' => { '-like' => $filter },
            'lower(display_name)'    => { '-like' => $filter },
        ],
    };
}

has 'sql_order' => ( is => 'ro', isa => 'HashRef', lazy_build => 1 );

sub _build_sql_order {
    my $self = shift;

    my $order = $self->order;
    die if $order and $order !~ /^\w+$/;
    $order = [qw(last_name first_name)] if !$order or $order eq 'name';

    my $group = $self->sql_group;

    return {
        order_by => $self->reverse ? { -desc => $order } : { -asc => $order },
        $group ? (group_by => $group) : (),
    }
}

has 'sql_group' => ( is => 'ro', isa => 'Maybe[Str]', lazy_build => 1);
sub _build_sql_group {}

sub get_results {
    my $self = shift;

    my ($sql, @bind) = $self->abstract->select(
        \$self->sql_from, $self->sql_cols, $self->sql_where,
        $self->sql_order, $self->limit, $self->offset,
    );

    my $sth = sql_execute($sql, @bind);
    return $sth->fetchall_arrayref({}) || [];
}

has 'abstract' => (
    is => 'ro', isa => 'SQL::Abstract', lazy_build => 1,
);
sub _build_abstract { sql_abstract() }

sub get_count {
    my $self = shift;
    my ($sql, @bind) = $self->abstract->select(
        \$self->sql_from, $self->sql_count, $self->sql_where,
    );
    return sql_singlevalue($sql, @bind);
}

sub typeahead_find {
    my $self = shift;
    $self->cleanup_filter;
    my @results;
    for my $row (@{$self->get_results}) {
        next if Socialtext::User::Default::Users->IsDefaultUser(
            username => $row->{driver_username},
        );
        my $user = Socialtext::User->new(user_id => $row->{user_id});
        $row->{best_full_name} = $user->guess_real_name;
        $row->{name} = $row->{driver_username};
        $row->{uri} = "/data/users/$row->{driver_username}";

        # Backwards compatibility stuff
        $row->{email} = $row->{email_address};
        $row->{username} = $row->{driver_username};
        push @results, $row;
    }
    return \@results;
}

__PACKAGE__->meta->make_immutable;
1;
