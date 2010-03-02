package Socialtext::User::Find::Container;
# @COPYRIGHT@
use Moose;
use Socialtext::SQL qw/get_dbh sql_execute/;
use Socialtext::SQL::Builder qw/sql_abstract/;
use Socialtext::String;
use Socialtext::User;
use List::MoreUtils qw/any/;
use Socialtext::UserSet qw(:const);
use namespace::clean -except => 'meta';

extends 'Socialtext::User::Find';

has direct => (is => 'ro', isa => 'Bool');
has container => (is => 'rw', isa => 'Maybe[Socialtext::UserSetContainer]');

sub _build_sql_from {
    my $self = shift;
    my $table = $self->direct ? 'user_set_include' : 'user_set_path';
    my $from = qq{
        $table
        JOIN users ON (from_set_id = user_id)
        JOIN "Role" USING(role_id)
    };
    unless ($self->minimal) {
        $from .= qq{
            JOIN "UserMetadata" USING(user_id)
            JOIN "Account"
                ON "UserMetadata".primary_account_id = "Account".account_id
        };
    }
    return $from;
}

sub _build_sql_cols {
    my $self = shift;
    my $cols = [
        'user_id', 'first_name', 'last_name',
        'email_address', 'driver_username',
        'array_accum(DISTINCT "Role".name) AS role_names',
    ];
    unless ($self->minimal) {
        push @$cols,
            '"UserMetadata".primary_account_id',
            '"Account".name AS primary_account_name',
            "to_char(creation_datetime, 'YYYY-MM-DD') AS creation_date",
            q{ 
                (
                    SELECT COUNT(*)
                      FROM user_set_path countable
                     WHERE countable.from_set_id = user_id
                       AND into_set_id } . PG_WKSP_FILTER . q{
                  GROUP BY from_set_id, user_id
                ) AS workspace_count
            },
    }
    return $cols;
}

has '+sql_where' => ( 'isa' => 'ArrayRef' );

sub _build_sql_where {
    my $self = shift;
    my $filter = $self->filter;

    my ($sub_stmt, @sub_bind) = sql_abstract->select(
        "user_sets_for_user", "1", {
            user_set_id => $self->container->user_set_id,
            user_id => $self->viewer->user_id,
        },
    );

    return [
        '-and' => [
            into_set_id => $self->container->user_set_id,

            # Limit the visible users unless 'all' is true
            $self->all ? () : ('-nest' => \["EXISTS ($sub_stmt)" => @sub_bind]),

            '-or' => [
                'lower(first_name)'      => { '-like' => $filter },
                'lower(last_name)'       => { '-like' => $filter },
                'lower(email_address)'   => { '-like' => $filter },
                'lower(driver_username)' => { '-like' => $filter },
                'lower(display_name)'    => { '-like' => $filter },
            ],
        ],
    ];
}

sub _build_sql_group {
    my $self = shift;
    my @group_cols = qw(
        user_id first_name last_name email_address driver_username
    );
    unless ($self->minimal) {
        push @group_cols, qw(
            primary_account_name primary_account_id creation_date
        );
    }

    return join ',', @group_cols;
}

sub get_results {
    my $self = shift;

    my $rows = $self->SUPER::get_results();

    for my $row (@$rows) {
        my @roles = map { Socialtext::Role->new(name => $_) }
            @{$row->{role_names} || []};

        my @sorted_role_names = map { $_->name }
            Socialtext::Role->SortByEffectiveness(roles => \@roles);

        delete $row->{role_names};
        $row->{role_name} = $sorted_role_names[-1];
        $row->{roles} = \@sorted_role_names;
        $row->{is_workspace_admin} =
            any { $_ eq 'admin' } @sorted_role_names;
    }

    return $rows;
}

__PACKAGE__->meta->make_immutable;
1;
