package Socialtext::User::Base;
# @COPYRIGHT@
use Moose;
use Readonly;
use Socialtext::Authz;
use Socialtext::SQL qw(sql_parse_timestamptz);
use Socialtext::Validate qw(validate SCALAR_TYPE);
use Socialtext::l10n qw(system_locale loc);
use Socialtext::MooseX::Types::Pg;
use Socialtext::MooseX::Types::UniStr;
use List::MoreUtils qw(part);
use namespace::clean -except => 'meta';

has 'user_id' => (is => 'rw', isa => 'Int', writer => '_set_user_id');
sub user_set_id { $_[0]->user_id }

has 'username'          => (is => 'rw', isa => 'Str');
has 'email_address'     => (is => 'rw', isa => 'Str');
has 'first_name'        => (is => 'rw', isa => 'UniStr', coerce => 1);
has 'last_name'         => (is => 'rw', isa => 'UniStr', coerce => 1);
has 'password'          => (is => 'rw', isa => 'Maybe[Str]');
has 'display_name'      => (is => 'rw', isa => 'UniStr', coerce => 1);
has 'driver_key'        => (is => 'rw', isa => 'Str');
has 'driver_unique_id'  => (is => 'rw', isa => 'Str');
has 'cached_at'         => (is => 'rw', isa => 'Pg.DateTime',
                            coerce => 1, required => 1);
has 'is_profile_hidden' => (is => 'rw', isa => 'Bool');
has 'missing'           => (is => 'ro', isa => 'Bool');
has 'private_external_id' => (is => 'rw', isa => 'Maybe[Str]');

has profile => (
    is         => 'ro',
    isa        => 'Maybe[Socialtext::People::Profile]',
    lazy_build => 1,
);
sub _build_profile {
    my $self = shift;
    return unless $self->can_use_plugin('people');
    return Socialtext::People::Profile->GetProfile($self->user_id);
}

# All fields/attributes that a "Socialtext::User::*" has.
Readonly our @fields => qw(
    user_id
    username
    email_address
    first_name
    last_name
    password
    display_name
);
Readonly our @other_fields => qw(
    driver_key
    driver_unique_id
    cached_at
    is_profile_hidden
    missing
    private_external_id
);
Readonly our @all_fields => (@fields, @other_fields);
Readonly our %all_fields => map {$_=>1} @all_fields;

sub UserFields {
    my $class = shift;
    my $proto_user = shift;

    # whatever is left in all is _not_ a Socialtext::User field.
    my %all = %$proto_user;
    my %user = 
       map { $_ => delete $all{$_} }
       grep { exists $all{$_} }
       @all_fields;

    return wantarray ? (\%user, \%all) : \%user;
}

sub preferred_name {
    my $self    = shift;
    my $profile = $self->profile;
    if ($profile) {
        return if $profile->fields->by_name('preferred_name')->is_hidden;
        return $profile->get_attr('preferred_name');
    }
    return;
}

sub GetFullName {
    my $class      = shift;
    my $first_name = shift;
    my $last_name  = shift;
    my $full_name;

    if (system_locale() eq 'ja') {
        $full_name = join ' ', grep { defined and length }
            $last_name, $first_name;
    }
    else {
        $full_name = join ' ', grep { defined and length }
        $first_name, $last_name;
    }
    return $full_name;
}

sub driver_name {
    my $self = shift;
    my ($name, $id) = split /:/, $self->driver_key();
    return $name;
}

sub driver_id {
    my $self = shift;
    my ($name, $id) = split /:/, $self->driver_key();
    return $id;
}

sub to_hash {
    my $self = shift;
    my $hash = {};
    foreach my $name (@fields) {
        my $value = $self->{$name};
        $hash->{$name} = "$value";  # to_string on some objects
    }
    return $hash;
}

sub can_use_plugin {
    my ($self, $plugin_name) = @_;

    my $authz = Socialtext::Authz->new();
    return $authz->plugin_enabled_for_user(
        plugin_name => $plugin_name,
        user => $self
    );
}

# Expires the user, so that any cached data is no longer considered fresh.
sub expire {
    my $self = shift;
    require Socialtext::User::Factory;  # avoid circular "use" dependency
    return Socialtext::User::Factory->ExpireUserRecord(
        user_id => $self->user_id
    );
}

# Validates passwords, to make sure that they are of required length.
{
    Readonly my $spec => { password => SCALAR_TYPE };
    sub ValidatePassword {
        my $class = shift;
        my %p = validate( @_, $spec );

        return ( loc("Passwords must be at least 6 characters long.") )
            unless length $p{password} >= 6;

        return;
    }
}

__PACKAGE__->meta->make_immutable(inline_constructor => 1);
1;

=head1 NAME

Socialtext::User::Base - Base class for User objects

=head1 DESCRIPTION

C<Socialtext::User::Base> implements a base class from which all User objects
are to be derived from.

=head1 METHODS

=over

=item B<Socialtext::User::*-E<gt>new($data)>

Creates a new user object based on the provided C<$data> (which could be a HASH
or a HASH-REF of data).

=item B<user_id()>

Returns the ID for the user.

=item B<username()>

Returns the username for the user.

=item B<email_address()>

Returns the e-mail address for the user, in all lower-case.

=item B<first_name()>

Returns the first name for the user.

=item B<last_name()>

Returns the last name for the user.

=item B<password()>

Returns the encrypted password for this user.

=item B<driver_name()>

Returns the name of the driver used for the data store this user was found in.
e.g. "Default", "LDAP".

=item B<driver_id()>

Returns the unique ID for the instance of the data store this user was found
in.  This unique ID is internal and likely has no meaning to a user.
e.g. "0deadbeef0".

=item B<driver_key()>

Returns the fully qualified driver key ("name:id") of the driver instance for
the data store this user was found in.  This key is internal and likely has no
meaning to a user.  e.g. "LDAP:0deadbeef0".

=item B<driver_unique_id()>

Returns the driver-specific unique identifier for this user.  This field is
internal and likely has no meaning to a user.
e.g. "cn=Bob,ou=Staff,dc=socialtext,dc=net"

item B<missing>

Returns a flag stating whether or not the User was "missing" last time we went
to check the data source for the User.  e.g. the User I<used to> exist in LDAP
but we can't find him there any more.

=item B<to_hash()>

Returns a hash reference representation of the user, suitable for using with
JSON, YAML, etc.  B<WARNING:> The encrypted password is included in this hash,
and should usually be removed before passing the hash over the threshold.

=item B<can_use_plugin($name)>

Returns a boolean indicating whether or not the User can use the given
C<$plugin>.  See also C<Socialtext::Account::is_plugin_enabled()>.

=item B<expire()>

Expires this user in the database.  May be a no-op for some homunculus types.

=item B<Socialtext::User::Base-E<gt>ValidatePassword(password=E<gt>$password)>

Validates the given password, returning a list of error messages if the
password is invalid.

=back

=head1 AUTHOR

Socialtext, Inc., C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2005-2008 Socialtext, Inc., All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
