package Socialtext::Rest::User;
# @COPYRIGHT@
use warnings;
use strict;
use base 'Socialtext::Rest::Entity';
use Socialtext::Functional 'hgrep';
use Socialtext::User;
use Socialtext::HTTP ':codes';
use Socialtext::JSON qw/decode_json/;

our $k;

# We punt to the permission handling stuff below.
sub permission { +{ GET => undef, PUT => undef } }
sub entity_name { "User " . $_[0]->username }
sub accounts { undef };

sub attribute_table_row {
    my ($self, $name, $value) = @_;
    return '' if $name eq 'accounts';
    return '' if $name eq 'groups';
    return $self->SUPER::attribute_table_row($name, $value);
}

sub get_resource {
    my ( $self, $rest ) = @_;

    my $acting_user = $self->rest->user;
    my $user = Socialtext::User->new( username => $self->username );

    # REVIEW: A permissions issue at this stage will result in a 404
    # which might not be the desired result. In a way it's kind of good,
    # in an information hiding sort of way, but....
    if (
        $user
        && (   $acting_user->is_business_admin()
            || $user->username eq $acting_user->username )
        ) {
        return +{
            ( hgrep { $k ne 'password' } %{ $user->to_hash } ),
            accounts => [
                map { $_->hash_representation(user_count=>1) }
                $user->accounts
            ],
            groups => [
                map { $_->to_hash(plugins=>1, show_account_ids=>1,
                                  show_admins => 1)
                    } $user->groups->all
            ],
        };
    }
    return undef;
}

sub PUT_json {
    my $self = shift;
    my $rest = shift;
    my $username = $self->username;
    return $self->not_authorized unless $rest->user->is_business_admin;

    my $user = eval { Socialtext::User->Resolve($username) };
    unless ($user) {
        $rest->header( -status => HTTP_400_Bad_Request );
        return 'No such user';
    }

    my $content = $rest->getContent();
    my $object = eval { decode_json( $content ) };
    if (!$object or ref($object) ne 'HASH') {
        $rest->header( -status => HTTP_400_Bad_Request );
        return 'Content should be a JSON hash.';
    }

    my $new_acct_id = $object->{primary_account_id};
    unless ($new_acct_id) {
        $rest->header( -status => HTTP_400_Bad_Request );
        return 'No primary_account_id specified!';
    }

    my $acct = Socialtext::Account->new(account_id => $new_acct_id);
    unless ($acct) {
        $rest->header( -status => HTTP_400_Bad_Request );
        return 'Invalid account ID';
    }

    eval { $user->primary_account($acct) };
    if ($@) {
        warn $@;
        $rest->header( -status => HTTP_400_Bad_Request );
        return $@;
    }

    $rest->header(
        -status => HTTP_204_No_Content,
        -Location => "/data/users/" . $user->user_id,
    );
    return '';
}


1;
