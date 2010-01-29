package Socialtext::User::Find::Workspace;
# @COPYRIGHT@
use Moose;
use Socialtext::SQL qw/get_dbh sql_execute/;
use Socialtext::SQL::Builder qw/sql_abstract/;
use Socialtext::String;
use Socialtext::User;
use List::MoreUtils qw/any/;
use namespace::clean -except => 'meta';

extends 'Socialtext::User::Find';

has direct => (is => 'ro', isa => 'Bool');
has workspace => (is => 'rw', isa => 'Socialtext::Workspace', required => 1);

sub _build_sql_from {
    my $self = shift;
    my $table = $self->direct ? 'user_set_include' : 'user_set_path';
    return qq{
        $table
        JOIN users ON (from_set_id = user_id)
        JOIN "Role" USING(role_id)
    };
}

sub _build_sql_cols {
    return [
        'user_id', 'first_name', 'last_name',
        'email_address', 'driver_username',
        'array_accum(DISTINCT "Role".name) AS role_names',
    ];
}

has '+sql_where' => ( 'isa' => 'ArrayRef' );

sub _build_sql_where {
    my $self = shift;
    my $filter = $self->filter;

    my ($sub_stmt, @sub_bind) = sql_abstract->select(
        "user_sets_for_user", "1", {
            user_set_id => $self->workspace->user_set_id,
            user_id => $self->viewer->user_id,
        },
    );

    return [
        '-and' => [
            into_set_id => $self->workspace->user_set_id,
            '-nest' => \["EXISTS ($sub_stmt)" => @sub_bind],
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

has '+sql_order' => ( isa => 'HashRef' );
sub _build_sql_order {
    return {
        order_by => [ qw(last_name first_name) ],
        group_by => 'user_id, first_name, last_name, '
                  . 'email_address, driver_username',
    };
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
