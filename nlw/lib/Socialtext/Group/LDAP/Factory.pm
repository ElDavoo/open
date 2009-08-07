package Socialtext::Group::LDAP::Factory;
# @COPYRIGHT@

use Moose;
use Socialtext::LDAP;
use Socialtext::LDAP::Config;
use Socialtext::User::LDAP::Factory;
use Socialtext::UserGroupRoleFactory;
use Socialtext::Log qw(st_log);
use DateTime::Duration;
use Net::LDAP::Util qw(escape_filter_value);
use namespace::clean -except => 'meta';

with qw(
    Socialtext::Group::Factory
);

has 'ldap_config' => (
    is => 'ro', isa => 'Socialtext::LDAP::Config',
    lazy_build => 1,
);

sub _build_ldap_config {
    my $self = shift;
    my $driver_id = $self->driver_id();
    return Socialtext::LDAP->ConfigForId($driver_id);
}

has 'ldap' => (
    is => 'ro', isa => 'Socialtext::LDAP::Base',
    lazy_build => 1,
);

sub _build_ldap {
    my $self = shift;
    return Socialtext::LDAP->new( $self->ldap_config );
}

# the LDAP store is *NOT* updateable; its read-only
sub can_update_store { 0 }

# empty stub; store is read-only, can't create a new Group in LDAP
sub Create {
    # XXX: should we throw a warning here?
}

# empty stub; store is read-only; can't update a Group in LDAP
sub Update {
    # XXX: should we throw a warning here?
}

# cache lifetime is based off of TTL for the LDAP server that we got the Group
# from.
sub _build_cache_lifetime {
    my $self = shift;
    return DateTime::Duration->new( seconds => $self->ldap_config->ttl );
}

# look up the Group in LDAP
sub _lookup_group {
    my ($self, $proto_group) = @_;

    # Get our LDAP Group Attribute Map.  If we don't have one, we *can't* look
    # up Groups, so just return right away.
    my $attr_map = $self->ldap_config->group_attr_map();
    return unless (%{$attr_map});

    # Map the fields in the provided proto-group to their underlying LDAP
    # attributes, and make sure that the values are properly escaped
    my $ldap_search_attrs = $self->_map_proto_to_ldap_attrs($proto_group);

    # build up the LDAP search options
    my @ldap_group_attrs =
        map  { $attr_map->{$_} }
        grep { $_ ne 'member_maps_to' }     # internal use, not an actual attr
        keys %{$attr_map};
    my %options = (
        attrs => [ @ldap_group_attrs ],
    );

    my ($dn) =
        grep { $_ =~ m{^(dn|distinguishedName)$}i }
        keys %{$ldap_search_attrs};
    if ($dn) {
        # LDAP lookup contains the DN in the search; do an exact search
        $options{'base'}   = $ldap_search_attrs->{$dn};
        $options{'scope'}  = 'base';
        $options{'filter'} = Socialtext::LDAP->BuildFilter(
            global => $self->ldap_config->group_filter(),
        );
    }
    else {
        # LDAP lookup has no DN; do a sub-tree search
        $options{'base'}   = $self->ldap_config->base();
        $options{'scope'}  = 'sub';
        $options{'filter'} = Socialtext::LDAP->BuildFilter(
            global => $self->ldap_config->group_filter(),
            search => $ldap_search_attrs,
        );
    }

    # Go look up the Group in LDAP
    my $ldap = $self->ldap;
    return unless $ldap;

    my $mesg = $ldap->search( %options );
    unless ($mesg) {
        st_log->error( "ST::Group::LDAP::Factory: no suitable LDAP response" );
        return;
    }
    if ($mesg->code) {
        st_log->error( "ST::Group::LDAP::Factory: LDAP error while finding Group; " . $mesg->error() );
        return;
    }
    if ($mesg->count() > 1) {
        st_log->error( "ST::Group::LDAP::Factory: found multiple matches for Group; $options{filter}" );
        return;
    }

    # Extract the Group from the LDAP response
    my $entry = $mesg->shift_entry();
    unless ($entry) {
        st_log->debug( "ST::Group::LDAP::Factory: unable to find Group in LDAP; $options{filter}" );
        return;
    }

    # Map the LDAP response back to a proto group
    $proto_group = $self->_map_ldap_entry_to_proto($entry);
    $proto_group->{driver_key} = $self->driver_key();
    $proto_group->{members} = [ $entry->get_value( $attr_map->{member_dn} ) ];
    return $proto_group;
}

sub _update_group_members {
    my $self        = shift;
    my $proto_group = shift;
    my $members     = $proto_group->{members};
    my $factory     = Socialtext::User::LDAP::Factory->new();

    for my $member ( @$members ) {
        my $user = $factory->GetUser( driver_unique_id => $member );
        Socialtext::UserGroupRoleFactory->Create( {
            user_id  => $user->user_id,
            group_id => $proto_group->{group_id},
            role_id  => Socialtext::UserGroupRoleFactory->DefaultRole->role_id,
        } );
    }
}

{
    my %proto_to_field = (
        # proto-group       => ST field (as noted in LDAP Group Attr Map)
        driver_unique_id    => 'group_id',
        driver_group_name   => 'group_name',
    );
    my %field_to_proto = reverse %proto_to_field;

    sub _map_proto_to_ldap_attrs {
        my ($self, $proto_group) = @_;

        my $attr_map = $self->ldap_config->group_attr_map();
        return unless (%{$attr_map});

        my %ldap_attrs;
        while (my ($proto_field, $proto_value) = each %{$proto_group}) {
            my $field = $proto_to_field{$proto_field};
            next unless $field;

            my $attr = $attr_map->{$field};
            next unless $attr;

            $ldap_attrs{$attr} = escape_filter_value($proto_value);
        }
        return \%ldap_attrs;
    }

    sub _map_ldap_entry_to_proto {
        my ($self, $entry) = @_;

        my $attr_map = $self->ldap_config->group_attr_map();
        return unless (%{$attr_map});

        my %proto_group;
        while (my ($field, $ldap_attr) = each %{$attr_map}) {
            my $proto_field = $field_to_proto{$field};
            next unless $proto_field;

            my $proto_value;
            if ($ldap_attr =~ m{^(dn|distinguishedName)$}i) {
                # DN isn't an attribute, its a Net::LDAP::Entry method
                $proto_value = $entry->dn();
            }
            else {
                $proto_value = $entry->get_value( $ldap_attr );
            }

            $proto_group{$proto_field} = $proto_value;
        }
        return \%proto_group;
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

Socialtext::Group::LDAP::Factory - LDAP sourced Group Factory

=head1 SYNOPSIS

  use Socialtext::Group;

  $factory = Socialtext::Group->Factory(driver_key => 'LDAP:abc123');

=head1 DESCRIPTION

C<Socialtext::Group::LDAP::Factory> provides an implementation of a Group
Factory that is sourced externally via LDAP.

Consumes the C<Socialtext::Group::Factory> Role.

=head1 METHODS

=over

=item B<$factory-E<gt>ldap_config()>

Returns a C<Socialtext::LDAP::Config> object for the LDAP configuration in use
by this LDAP Group Factory.

=item B<$factory-E<gt>ldap()>

Returns a C<Socialtext::LDAP::*> object, holding the connection to the LDAP
server that this Factory presents Groups from.

=item B<$factory-E<gt>can_update_store()>

Returns false; LDAP Group Factories are B<read-only>.

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
