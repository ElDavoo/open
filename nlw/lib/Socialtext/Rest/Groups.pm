package Socialtext::Rest::Groups;
# @COPYRIGHT@
use Moose;
extends 'Socialtext::Rest::Collection';
use Socialtext::Group;
use Socialtext::HTTP ':codes';
use Socialtext::JSON qw/decode_json encode_json/;
use namespace::clean -except => 'meta';

# Anybody can see these, since they are just the list of workspaces the user
# has 'selected'.
sub permission { +{} }

sub collection_name { 'Groups' }

sub _entities_for_query {
    my $self = shift;
    my $user = $self->rest->user();

    my $group_cursor = Socialtext::Group->All();
    if ($user->is_business_admin) {
        return $group_cursor->all;
    }

    my @groups;
    while (my $g = $group_cursor->next) {
        eval {
            if ($g->creator->user_id == $user->user_id 
                    or $g->has_user($user)) {
                push @groups, $g;
            }
        };
        warn $@ if $@;
    }
    return @groups;
}

sub _entity_hash {
    my $self  = shift;
    my $group = shift;

    return $group->to_hash( show_members => $self->{_show_members} );
}

around get_resource => sub {
    my $orig = shift;
    my $self = shift;

    $self->{_show_members} = $self->rest->query->param('show_members') ? 1 : 0;
    return $orig->($self, @_);
};

override extra_headers => sub {
    my $self = shift;
    my $resource = shift;

    return (
        '-cache-control' => 'private',
    );
};

sub POST_json {
    my $self = shift;
    my $rest = shift;

    my $data = eval { decode_json( $rest->getContent() ) };
    if ($@) {
        $rest->header(
            -status => HTTP_400_Bad_Request,
        );
        return "Bad JSON: $@";
    }

    unless ($self->user_can('is_business_admin')) {
        $rest->header(
            -status => HTTP_401_Unauthorized,
        );
        return '';
    }

    unless ( defined $data and ref($data) eq 'HASH' ) {
        $rest->header(
            -status => HTTP_400_Bad_Request,
        );
        return '';
    }

    my $account_id = $data->{account_id}
        || Socialtext::Account->Default->account_id;

    my $account = Socialtext::Account->new(account_id => $account_id);
    unless ($account) {
        $rest->header(
            -status => HTTP_400_Bad_Request,
        );
        return "account_id ($account_id) is not a valid account_id";
    }

    my $group;
    my $name = $data->{ldap_dn} || $data->{name};
    eval {
        if (my $ldap_dn = $data->{ldap_dn}) {
            # Check if Group already exists
            my $proto = Socialtext::Group->GetProtoGroup(driver_unique_id => $ldap_dn);
            if ($proto) {
                $rest->header(
                    -status => HTTP_409_Conflict,
                );
                return "$ldap_dn is already a group";
            }

            # Vivify the Group, thus loading it into ST.
            $group = Socialtext::Group->GetGroup(
                driver_unique_id   => $ldap_dn,
                primary_account_id => $account->account_id,
            );
        }
        elsif (my $group_name = $data->{name}) {
            # Regular Socialtext Group
            $group = Socialtext::Group->Create({
                driver_group_name => $group_name,
                primary_account_id => $account->account_id,
                created_by_user_id => $self->rest->user->user_id,
            });
        }
        else {
            $rest->header(
                -status => HTTP_400_Bad_Request,
            );
            return "Either ldap_dn or name is required to create a group.";
        }
    };
    if (my $err = $@) {
        if ($err =~ m/duplicate key violates/) {
            $rest->header( -status => HTTP_409_Conflict );
            return "Error creating group: $name already exists.";
        }
        $rest->header( -status => HTTP_400_Bad_Request );
        return "Error creating group: $err";
    }

    unless ($group) {
        $rest->header(
            -status => HTTP_400_Bad_Request,
        );
        return "Could not create the group";
    }


    $rest->header(
        -status => HTTP_201_Created,
    );
    return encode_json($group->to_hash);
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 NAME

Socialtext::Rest::Groups - List groups on the system.

=head1 SYNOPSIS

    GET /data/groups

=head1 DESCRIPTION

View the list of groups.  You can only see groups you created or are a
member of, unless you are a business admin, in which case you can see
all groups.

=cut
