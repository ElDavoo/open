package Socialtext::Rest::Groups;
# @COPYRIGHT@
use Moose;
extends 'Socialtext::Rest::Collection';
use Socialtext::Group;
use Socialtext::HTTP ':codes';
use Socialtext::JSON qw/decode_json/;
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
    my $data = decode_json( $rest->getContent() );

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

    my $account_id = $data->{account_id};
    unless ($account_id) {
        $rest->header(
            -status => HTTP_400_Bad_Request,
        );
        return "Missing an account_id";
    }

    my $account = Socialtext::Account->new(account_id => $account_id);
    unless ($account) {
        $rest->header(
            -status => HTTP_400_Bad_Request,
        );
        return "account_id ($account_id) is not a valid account_id";
    }

    my $ldap_dn = $data->{ldap_dn};
    unless ($ldap_dn) {
        $rest->header(
            -status => HTTP_400_Bad_Request,
        );
        return "Missing a ldap_dn";
    }


    # Check if Group already exists
    my $proto = Socialtext::Group->GetProtoGroup(driver_unique_id => $ldap_dn);
    if ($proto) {
        $rest->header(
            -status => HTTP_409_Conflict,
        );
        return "$ldap_dn is already a group";
    }

    # Vivify the Group, thus loading it into ST.
    my $group = Socialtext::Group->GetGroup(
        driver_unique_id   => $ldap_dn,
        primary_account_id => $account->account_id,
    );

    unless ($group) {
        $rest->header(
            -status => HTTP_400_Bad_Request,
        );
        return "Could not create the group";
    }


    $rest->header(
        -status => HTTP_201_Created,
    );
    return '';
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
