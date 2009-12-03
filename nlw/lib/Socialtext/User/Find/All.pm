package Socialtext::User::Find::All;
# @COPYRIGHT@
use Moose;
use Socialtext::SQL qw(sql_execute);
use namespace::clean -except => 'meta';

extends 'Socialtext::User::Find';

# We *ONLY* allow for searches across all Accounts to be done by Business
# Admins.
before 'typeahead_find' => sub {
    my $self = shift;
    unless ($self->viewer->is_business_admin) {
        die "Only Business Admin's can search for Users across all Accounts.\n";
    }
};

sub get_results {
    my $self = shift;

    my $sql = q{
        SELECT user_id, first_name, last_name, email_address, driver_username
        FROM users
        WHERE (
            lower(first_name) LIKE $1 OR
            lower(last_name) LIKE $1 OR
            lower(email_address) LIKE $1 OR
            lower(driver_username) LIKE $1 OR
            lower(display_name) LIKE $1
        )
        ORDER BY last_name ASC, first_name ASC
        LIMIT $2 OFFSET $3
    };

    #local $Socialtext::SQL::PROFILE_SQL = 1;
    my $sth = sql_execute($sql,
        $self->filter, $self->limit, $self->offset
    );

    return $sth->fetchall_arrayref({}) || [];
}

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Socialtext::User::Find::All - Finds *ALL* Users, for ReST typeahead

=head1 SYNOPSIS

  $finder = Socialtext::User::Find::All->new(
      viewer => $self->rest->user,
      limit  => $limit,
      offset => $offset,
      filter => $filter,
  );
  $results = eval { $finder->typeahead_find };

=head1 DESCRIPTION

C<Socialtext::User::Find::All> is a typeahead/lookahead User finder, which
allows for Business Admins to find B<any/all> Users on the system.

Unlike C<Socialtext::User::Find>, which only shows results for Users that the
viewer happens to share an Account with, C<Socialtext::User::Find::All> can
find Users in B<any> Account.  This extra level of visibility, however,
B<requires> that the viewer have the C<is_business_admin> privilege;
normal/regular Users are not allowed to find Users across Accounts.

=cut
