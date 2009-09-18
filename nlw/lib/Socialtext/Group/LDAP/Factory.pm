package Socialtext::Group::LDAP::Factory;
# @COPYRIGHT@

use Moose;
use Socialtext::LDAP;
use Socialtext::LDAP::Config;
use Socialtext::User::LDAP::Factory;
use Socialtext::Log qw(st_log);
use DateTime::Duration;
use Net::LDAP::Util qw(escape_filter_value);
use namespace::clean -except => 'meta';

with qw(
    Socialtext::Group::Factory
);

sub BUILD {
    my $self = shift;

    # If we can't find our LDAP Config, throw a fatal error
    my $config = $self->ldap_config();
    unless (defined $config) {
        my $driver_id = $self->driver_id();
        die "Can't find configuration '$driver_id' for LDAP Group Factory\n";
    }
}

has 'ldap_config' => (
    is => 'ro', isa => 'Maybe[Socialtext::LDAP::Config]',
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

# the LDAP store *is* cacheable
sub is_cacheable { 1 }

# Returns list of available Groups
sub Available {
    my $self = shift;
    my %p    = @_;
    my $all  = $p{all} || 0;

    # Get our LDAP Group Attribute Map.  If we don't have one, we *can't* look
    # up Groups, so just return right away.
    my $attr_map = $self->ldap_config->group_attr_map();
    return unless (%{$attr_map});

    # Build up the LDAP search options
    my @ldap_group_attrs =
        map  { $attr_map->{$_} }
        grep { $_ ne 'member_maps_to' }     # internal use, not an actual attr
        keys %{$attr_map};

    my %options = (
        base    => $self->ldap_config->base(),
        scope   => 'sub',
        attrs   => [ @ldap_group_attrs ],
        filter  => Socialtext::LDAP->BuildFilter(
            global => $self->ldap_config->group_filter(),
        ),
    );

    # Look up the list of Groups in LDAP
    my $ldap = $self->ldap;
    return unless $ldap;

    my $mesg = $ldap->search( %options );
    unless ($mesg) {
        st_log->error( "ST::Group::LDAP::Factory: no suitable LDAP response" );
        return;
    }
    if ($mesg->code) {
        st_log->error( "ST::Group::LDAP::Factory: LDAP error while listing available Groups; " . $mesg->error() );
        return;
    }

    # Extract the Groups from the LDAP response
    my @available;
    while (my $entry = $mesg->shift_entry()) {
        my $proto        = $self->_map_ldap_entry_to_proto($entry);
        my $exists_in_db = $self->_get_cached_group($proto);
        my @members      = $entry->get_value($attr_map->{member_dn});

        next unless (defined $exists_in_db || $all);

        my $group = {
            driver_key          => $self->driver_key(),
            driver_group_name   => $proto->{driver_group_name},
            driver_unique_id    => $proto->{driver_unique_id},
            already_created     => defined $exists_in_db ? 1 : 0,
            member_count        => scalar @members,
        };

        push @available, $group;
    }

    # Results have a pre-determined sort order
    my @sorted =
        sort { $a->{driver_group_name} cmp $b->{driver_group_name} }
        @available;
    return @sorted;
}

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
    my $response = $self->_map_ldap_entry_to_proto($entry);
    $response->{driver_key} = $self->driver_key();
    $response->{members}    = [ $entry->get_value( $attr_map->{member_dn} ) ];
    foreach my $passthru (qw( primary_account_id )) {
        if (defined $proto_group->{$passthru}) {
            $response->{$passthru} ||= $proto_group->{$passthru};
        }
    }
    return $response;
}

sub _update_group_members {
    my $self    = shift;
    my $homey   = shift;
    my $members = shift;
    my $group   = Socialtext::Group->new(homunculus => $homey);

    # Get the list of all of the existing Users in the Group, which we'll
    # whittle down to *just* those that are no longer members and can have
    # their UGRs deleted.
    my %last_cached_users =
        map { $_->homunculus->driver_unique_id => $_ }
        $group->users->all;

    # Keep track of DNs that we've looked up already, so we're not looking
    # them up repeatedly.  This prevents infinite recursion on nested Groups.
    my %seen_dns;

    # Take all of the "Member DNs" that we were given, and add all of them to
    # ourselves.  Be forewarned, though, that the DN _may_ be a User, but it
    # _may_ be a *Group* (and there's no way to tell without actually looking
    # it up).
    my @left_to_add = @{$members};
    while (@left_to_add) {
        # get the next DN, skipping it if we've looked this one up already
        my $dn = shift @left_to_add;
        next if ($seen_dns{$dn}++);

        # if this DN existed in the Group before, leave it unchanged
        next if (delete $last_cached_users{$dn});

        # look this DN up as a User, and give them an UGR
        my $user = Socialtext::User->new( driver_unique_id => $dn );
        if ($user) {
            $group->add_user( user => $user );
            next;
        }

        # look this DN up as a Group, and add its membership list to the list
        # of things we have left to lookup
        my $nested_proto = $self->_lookup_group( { driver_unique_id => $dn } );
        if ($nested_proto) {
            push @left_to_add, @{$nested_proto->{members}};
            next;
        }

        # didn't find this DN as a User or Group, log a warning
        st_log->warning( "Unable to find User/Group in LDAP for DN '$dn'; skipping" );
    }

    # Remove Users that *used to* be in the Group, but that don't appear to be
    # any more.
    for my $user (values %last_cached_users) {
        $group->remove_user( user => $user );
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

=item B<$factory-E<gt>is_cacheable()>

Returns true; LDAP Group stores should be cached locally.

=back

=head1 NOTES

In an Active Directory, User records contain a C<memberOf> attribute, which
points I<back> to the Group object DN ("Hey, I'm a member of I<that> Group").
B<However>, the Group record contains a C<member> attribute which contains a
list of User DNs (one for each User) ("Hey, I<these> Users are member of this
Group").  Fortunately, these C<member> and C<memberOf> attributes are linked
and are updated automatically by Active Directory; updating "Group.member"
automatically updates the "User.memberOf" attribute.

As a result, B<we> only ever have to be concerned with enumerating the
"Group.member" attribute; that's going to contain the full list of DNs for
Users/Groups/etc. that are members of this Group.  We do I<not> have to also
go out and scour AD for Users that are a C<memberOf> the Group, as we already
got the full list of those from querying the Group object directly.

Reference: http://www.informit.com/articles/article.aspx?p=26136&seqNum=5

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
