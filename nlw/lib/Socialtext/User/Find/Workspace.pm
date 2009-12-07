package Socialtext::User::Find::Workspace;
# @COPYRIGHT@
use Moose;
use Socialtext::SQL qw/get_dbh sql_execute/;
use Socialtext::String;
use Socialtext::User;
use List::MoreUtils qw/any/;
use namespace::clean -except => 'meta';

extends 'Socialtext::User::Find';

has workspace => (is => 'rw', isa => 'Socialtext::Workspace', required => 1);

sub get_results {
    my $self = shift;

    my $sql = q{
        SELECT user_id, first_name, last_name,
               email_address, driver_username, "Role".name AS role_name
        FROM user_set_path
        JOIN users ON (from_set_id = user_id)
        JOIN "Role" USING(role_id)
        WHERE into_set_id = $3
          AND EXISTS (
            SELECT 1
              FROM user_sets_for_user
             WHERE user_set_id = $3
               AND user_id = $2
          )
          AND (
            lower(first_name) LIKE $1 OR
            lower(last_name) LIKE $1 OR
            lower(email_address) LIKE $1 OR
            lower(driver_username) LIKE $1
          )
        ORDER BY last_name ASC, first_name ASC
        LIMIT $4 OFFSET $5
    };

    #local $Socialtext::SQL::PROFILE_SQL = 1;
    my $sth = sql_execute($sql, 
        $self->filter, $self->viewer->user_id, $self->workspace->user_set_id,
        $self->limit, $self->offset,
    );

    my $rows = $sth->fetchall_arrayref({}) || [];
    for my $row (@$rows) {
        $row->{is_workspace_admin} = $row->{role_name} eq 'admin';
    }

    return $rows;
}

__PACKAGE__->meta->make_immutable;
1;
