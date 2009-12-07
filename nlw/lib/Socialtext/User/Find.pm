package Socialtext::User::Find;
# @COPYRIGHT@
use Moose;
use Socialtext::SQL qw/get_dbh sql_execute/;
use Socialtext::String;
use Socialtext::User;
use namespace::clean -except => 'meta';

has viewer => (is => 'rw', isa => 'Socialtext::User', required => 1);
has limit => (is => 'rw', isa => 'Maybe[Int]');
has offset => (is => 'rw', isa => 'Maybe[Int]');
has filter => (is => 'rw', isa => 'Maybe[Str]');

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

sub get_results {
    my $self = shift;

    my $sql = q{
        SELECT DISTINCT other.user_id, first_name, last_name,
                        email_address, driver_username
          FROM user_sets_for_user viewer
          JOIN user_sets_for_user other USING (user_set_id)
          JOIN users ON (other.user_id = users.user_id)
         WHERE viewer.user_id = $2
           AND (
            lower(first_name) LIKE $1 OR
            lower(last_name) LIKE $1 OR
            lower(email_address) LIKE $1 OR
            lower(driver_username) LIKE $1 OR
            lower(display_name) LIKE $1
         )
         ORDER BY last_name ASC, first_name ASC
         LIMIT $3 OFFSET $4
    };

    #local $Socialtext::SQL::PROFILE_SQL = 1;
    my $sth = sql_execute($sql, 
        $self->filter, $self->viewer->user_id, $self->limit, $self->offset
    );

    return $sth->fetchall_arrayref({}) || [];
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
