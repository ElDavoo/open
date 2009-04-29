package Socialtext::LDAP;
# @COPYRIGHT@

# NOTE: if you change the behaviour here, please make sure all of the pages
# listed in the "SEE ALSO" section are updated accordingly.

use strict;
use warnings;
use Socialtext::Cache;
use Socialtext::Log qw(st_log);
use Socialtext::LDAP::Config;

# Enables/disables the LDAP connection cache
our $CacheEnabled = 1;

sub new {
    my ($class, $driver_or_config) = @_;

    my $config = $class->ConfigForId($driver_or_config);
    return unless $config;

    # connect to the LDAP server
    return Socialtext::LDAP->connect($config);
}

sub ConfigForId {
    my ($class, $driver_or_config) = @_;

    my $config;
    if (ref($driver_or_config) &&
        $driver_or_config->isa('Socialtext::LDAP::Config'))
    {
        $config = $driver_or_config;
    }
    else {
        # get configuration object for this LDAP configuration
        $config = $driver_or_config
            ? Socialtext::LDAP->config($driver_or_config)
            : Socialtext::LDAP->default_config();
    }

    return $config;
}

sub default_config {
    my $config = Socialtext::LDAP::Config->load();
    return $config;
}

sub config {
    my ($class, $driver_id) = @_;
    my ($config)
        = grep { $_->id eq $driver_id }
        Socialtext::LDAP::Config->load();
    return $config;
}

sub connect {
    my ($class, $config) = @_;

    # check to see if we've already got an open connection to this LDAP server
    if ($CacheEnabled) {
        my $conn = ConnectionCache()->get($config->id);
        return $conn if $conn;
    }

    # create a connection to the LDAP server, and bind it
    my $conn = _get_connection( $config );
    return unless ($conn);

    my $rc = $conn->bind();

    # cache the connection so we can re-use it later
    if ($rc && $CacheEnabled) {
        ConnectionCache()->set($config->id, $conn);
    }

    # return the connection status to the caller
    return $rc;
}

sub ConnectionCache {
    return Socialtext::Cache->cache('ldap-connections');
}

sub available {
    my @available = map { $_->id } Socialtext::LDAP::Config->load();
    return @available;
}

sub authenticate {
    my ($class, %opts) = @_;
    my $driver_id = $opts{driver_id};
    my $user_id   = $opts{user_id};
    my $password  = $opts{password};

    # Turn off connection cache, so Authen *always* gets its own LDAP
    # connection.
    local $Socialtext::LDAP::CacheEnabled = 0;

    # get an LDAP connection
    my $ldap = $class->new($driver_id);
    return unless $ldap;

    # attempt to authenticate the user against LDAP
    return $ldap->authenticate($user_id, $password);
}

sub _get_connection {
    my $config = shift;

    # get plug-in module which implements the back-end
    my $backend = _get_class( $config->backend() );
    eval "use $backend";
    if ($@) {
        st_log->error( "ST::LDAP: unable to load LDAP back-end plug-in '$backend'; $@" );
        return;
    }

    # instantiate the back-end
    my $conn = eval { $backend->new( $config ) };
    if ($@) {
        st_log->error( "ST::LDAP; unable to instantiate LDAP back-end plug-in '$backend'; $@" );
        return;
    }
    return $conn;
}

sub _get_class {
    my $backend = shift;
    # use default back-end unless one was provided
    $backend ||= 'Base';
    # return class used to implement back-end
    my $ldap_class = 'Socialtext::LDAP::' . $backend;
    return $ldap_class;
}

1;

=head1 NAME

Socialtext::LDAP - LDAP connection factory

=head1 SYNOPSIS

  use Socialtext::LDAP;

  # connect to default LDAP server
  $ldap = Socialtext::LDAP->new();

  # get default LDAP configuration
  $config = Socialtext::LDAP->default_config();

  # get configuration for a specific LDAP server
  $config = Socialtext::LDAP->config($driver_id);

  # connect to LDAP server using given configuration
  $ldap = Socialtext::LDAP->connect($config);

  # list the known/configured LDAP connections
  @driver_ids = Socialtext::LDAP->available();

  # authenticate a user against an LDAP server
  $auth_ok = Socialtext::LDAP->authenticate(
      user_id  => $user->user_id(),
      password => $password,
      );

=head1 DESCRIPTION

C<Socialtext::LDAP> implements a factory for LDAP connections.

=head1 METHODS

=over

=item B<Socialtext::LDAP-E<gt>new($driver_id)>

Creates a new LDAP connection, for the LDAP configuration identified by the
given driver identifier.  If no driver identifier is provided, a default LDAP
connection will be made.

=item B<Socialtext::LDAP-E<gt>default_config()>

Retrieves the LDAP configuration for the default LDAP connection (the first
one found in the LDAP configuration file), returning it back to the caller
as a C<Socialtext::LDAP::Config> object.

=item B<Socialtext::LDAP-E<gt>config($driver_id)>

Retrieves the configuration for the LDAP configuration identified by the given
driver identifier, returning it back to the caller as a
C<Socialtext::LDAP::Config> object.  If we're unable to locate the specified
LDAP connection, this method returns empty-handed.

=item B<Socialtext::LDAP-E<gt>connect($config)>

Connects to an LDAP server, using the configuration in the provided
C<Socialtext::LDAP::Config> object.

=item B<Socialtext::LDAP-E<gt>available()>

Returns a list of driver identifiers for all of the configured LDAP
connections.

=item B<Socialtext::LDAP-E<gt>authenticate(%opts)>

Attempts to authenticate a user against an LDAP server, using the provided
options.  Returns true if authentication is successful, false otherwise.

Required options:

=over

=item driver_id

The unique identifier for the LDAP configuration instance that the user
resides in.  Needed to identify which LDAP server it is that we're trying to
authenticate the user against.

Unless provided, authentication is performed against the default LDAP
configuration.

=item user_id

The unique ID for the User we're attempting to authenticate.

=item password

The password to attempt authentication with.

=back

=back

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Socialtext, Inc., All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<http://www.socialtext.net/open/index.cgi?howto_configure_the_ldap_plugin>.

=cut
