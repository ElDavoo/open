package Socialtext::User::Restrictions;

use Moose;

use Carp qw(croak);
use Digest::SHA1 qw(sha1_base64);
use List::Util qw(first);
use Socialtext::AppConfig;
use Socialtext::Date;
use Socialtext::MultiCursor;
use Socialtext::SQL qw(:exec sql_txn);
use Socialtext::SQL::Builder qw(sql_abstract);
use Socialtext::Timer qw(time_scope);
use namespace::clean -except => 'meta';

my $TABLE    = 'user_restrictions';
my $COLUMNS  = [qw( user_id restriction_type token expires_at workspace_id )];
my $PKEY     = [qw( user_id restriction_type )];
my $REQUIRED = [qw( user_id restriction_type )];

sub Create {
    my $class = shift;
    my $proto = shift;
    my $t     = time_scope('user_restriction_create');

    # validate the inbound data, and assign defaults
    $class->ValidateAndCleanData(undef, $proto);

    # Create the record in the DB
    $class->CreateRecord($proto);

    # Create the restriction object and return that back to the caller
    return $class->_instantiate($proto);
}

sub ValidateAndCleanData {
    my $class       = shift;
    my $restriction = shift;
    my $proto       = shift;

    # are we creating a new restriction, or updating an existing one?
    my $is_create = defined $restriction ? 0 : 1;

    # new Restrictions need a "token"
    $class->_validate_assign_token($proto) if ($is_create);

    # new Restrictions need an "expires_at"
    $class->_validate_assign_expires_at($proto) if ($is_create);

    # new Restrictions get a NULL Workspace Id
    $class->_validate_assign_workspace_id($proto) if ($is_create);

    # can't create multiple Restrictions for a User of a given type
    $class->_validate_check_unique_type_for_user($proto) if ($is_create);
}

sub _validate_assign_token {
    my $class = shift;
    my $proto = shift;
    unless ($proto->{token}) {
        $proto->{token} = sha1_base64(
            $proto->{user_id},
            time,
            Socialtext::AppConfig->MAC_secret
        );
    }
}

sub _validate_assign_expires_at {
    my $class = shift;
    my $proto = shift;
    unless ($proto->{expires_at}) {
        $proto->{expires_at} = $class->default_expires_at;
    }
}

sub default_expires_at {
    return Socialtext::Date->now->add(weeks => 2);
}

sub _validate_assign_workspace_id {
    my $class = shift;
    my $proto = shift;
    unless (exists $proto->{workspace_id}) {
        $proto->{workspace_id} = undef;
    }
}

sub _validate_check_unique_type_for_user {
    my $class = shift;
    my $proto = shift;

    my $pkey = $class->_filter_pkey_columns($proto);
    my ($sql, @bind) = sql_abstract->select($TABLE, $COLUMNS, $pkey);
    my $sth  = sql_execute($sql, @bind);
    my $rows = $sth->rows;

    if ($rows) {
        my $type = $proto->{restriction_type};
        croak "Can't create a duplicate $type for User";
    }
}

around 'CreateRecord' => \&sql_txn;
sub CreateRecord {
    my $class = shift;
    my $proto = shift;

    # Get the list of valid columns, and check for required attributes
    my $valid   = $class->_filter_valid_columns($proto);
    my $missing = first { not defined $valid->{$_} } @{$REQUIRED};
    die "need a $missing attribute to create restriction" if $missing;

    # INSERT the record into the DB
    my ($sql, @bind) = sql_abstract->insert($TABLE, $valid);
    sql_execute($sql, @bind);
}

sub _instantiate {
    my $class = shift;
    my $proto = shift;
    my $type  = $proto->{restriction_type};
    my $pkg   = 'Socialtext::User::Restrictions::' . $type;

    eval "require $pkg";
    if ($@) {
        croak "Couldn't load User Restriction type '$type'; $@";
    }

    return $pkg->new($proto);
}

sub CreateOrReplace {
    my $class = shift;
    my $proto = shift;
    my $t     = time_scope('user_restriction_create_or_replace');

    my $pkey   = $class->_filter_pkey_columns($proto);
    my $record = $class->Get($pkey);
    if ($record) {
        # replace
        return $class->Update($record, $proto);
    }
    return $class->Create($proto);
}

sub Get {
    my $class = shift;
    my $proto = shift;
    my $t     = time_scope('user_restriction_get');
    my $valid = $class->_filter_valid_columns($proto);

    my ($sql, @bind) = sql_abstract->select($TABLE, $COLUMNS, $valid);
    my $sth = sql_execute($sql, @bind);
    my $row = $sth->fetchrow_hashref;
    return unless $row;
    return $class->_instantiate($row);
}

sub FetchByToken {
    my $class = shift;
    my $token = shift;
    my ($sql, @bind)
        = sql_abstract->select($TABLE, $COLUMNS, { token => $token });
    my $sth = sql_execute($sql, @bind);
    my $row = $sth->fetchrow_hashref();
    return unless $row;
    return $class->_instantiate($row);
}

sub AllForUser {
    my $class      = shift;
    my $maybe_user = shift;
    my %p          = @_;
    my $t          = time_scope('user_restriction_all_for_user');
    my $user_id
        = (ref($maybe_user) && $maybe_user->can('user_id'))
        ? $maybe_user->user_id
        : $maybe_user;

    my ($sql, @bind)
        = sql_abstract->select($TABLE, $COLUMNS, { user_id => $user_id });
    my $sth = sql_execute($sql, @bind);
    return Socialtext::MultiCursor->new(
        iterables => [ $sth->fetchall_arrayref({}) ],
        apply     => sub { $class->_instantiate(shift) },
    );
}

around 'UpdateRecord' => \&sql_txn;
sub UpdateRecord {
    my $class = shift;
    my $proto = shift;

    # Get the list of valid DB columns, the pkey, and the values to update
    my $valid  = $class->_filter_valid_columns($proto);
    my $pkey   = $class->_filter_pkey_columns($valid);
    my $values = $class->_filter_non_pkey_columns($valid);

    # If we don't have anything to update, don't
    return unless %{$values};

    # UPDATE the record in the DB.
    my ($sql, @bind) = sql_abstract->update($TABLE, $values, $pkey);
    my $sth  = sql_execute($sql, @bind);
    my $rows = $sth->rows;

    return $rows;   # count of records updated
}

sub Update {
    my $class       = shift;
    my $restriction = shift;
    my $updates     = shift;
    my $t           = time_scope('user_restriction_update');

    # validate the inbound data
    $class->ValidateAndCleanData($restriction, $updates);

    # Update the record in the DB for this Restriction
    my $pkey = $class->_filter_pkey_columns($restriction);
    my $to_update = {
        %{$updates},
        %{$pkey},
    };
    $class->UpdateRecord($to_update);

    # Merge the updates back into the Restriction object
    my $to_merge = $class->_filter_non_pkey_columns($to_update);
    foreach my $attr (keys %{$to_merge}) {
        my $setter = $restriction->meta->find_attribute_by_name($attr);
        next unless $setter;
        $setter->set_value($restriction, $to_update->{$attr});
    }
    return $restriction;
}

sub Delete {
    my $class       = shift;
    my $restriction = shift;
    my $pkey        = $class->_filter_pkey_columns($restriction);
    $class->DeleteRecord($pkey, @_);
}

around 'DeleteRecord' => \&sql_txn;
sub DeleteRecord {
    my $class = shift;
    my $proto = shift;

    my $where = $class->_filter_valid_columns($proto);
    my ($sql, @bind) = sql_abstract->delete($TABLE, $where);
    my $sth  = sql_execute($sql, @bind);
    my $rows = $sth->rows;

    return $rows;   # count of records deleted
}

sub _filter_valid_columns {
    my $class = shift;
    my $proto = shift;
    my $valid = +{
        map  { $_ => $proto->{$_} }
        grep { exists $proto->{$_} }
        @{$COLUMNS}
    };
    return $valid;
}

sub _filter_pkey_columns {
    my $class = shift;
    my $proto = shift;
    my $pkey  = +{
        map  { $_ => $proto->{$_} }
        grep { exists $proto->{$_} }
        @{$PKEY}
    };
    return $pkey;
}

sub _filter_non_pkey_columns {
    my $class = shift;
    my $proto = shift;

    # Build a list of the non-primary-key columns
    my %columns = map { $_ => 1 } @{$COLUMNS};
    map { delete $columns{$_} } @{$REQUIRED};

    # GET the values for all of those columns
    my $values = +{
        map  { $_ => $proto->{$_} }
        grep { exists $proto->{$_} }
        keys %columns
    };
    return $values;
}

1;

=head1 NAME

Socialtext::User::Restrictions - User Restrictions factory

=head1 SYNOPSIS

  use Socialtext::User::Restrictions;

  # Get all of the restrictions for a User
  my $iter = Socialtext::User::Restrictions->AllForUser($user_or_id);

  # Get a specific restriction, by its token
  my $restriction = Socialatext::User::Restrictions->FetchByToken($token);

=head1 DESCRIPTION

=head1 METHODS

=head1 COPYRIGHT

=cut
