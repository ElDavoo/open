package Socialtext::Rest::AccountUsers;
# @COPYRIGHT@

use strict;
use warnings;
use base 'Socialtext::Rest::Collection';
use Socialtext::Account;
use Socialtext::JSON qw/decode_json/;
use Socialtext::HTTP ':codes';
use Socialtext::String;
use Socialtext::User;

sub allowed_methods { 'POST', 'GET', 'DELETE' }
sub collection_name { 
    my $acct =  ( $_[0]->acct =~ /^\d+$/ ) 
            ? 'with ID ' . $_[0]->acct
            : $_[0]->acct; 
    return 'Users in Account ' . $acct;
}

sub workspace { return Socialtext::NoWorkspace->new() }
sub ws { '' }

sub POST_json {
    my $self = shift;
    my $rest = shift;

    unless ($self->user_can('is_business_admin')) {
        $rest->header( -status => HTTP_401_Unauthorized );
        return '';
    }

    my $account = Socialtext::Account->new( 
        name => Socialtext::String::uri_unescape( $self->acct ),
    );
    unless ( defined $account ) {
        $rest->header( -status => HTTP_404_Not_Found );
        return "Could not find that account.";
    }

    my $data = eval { decode_json( $rest->getContent ) };
    if ($@) {
        $rest->header( -status => HTTP_400_Bad_Request );
        return "Could not parse JSON";
    }

    my $user_id = $data->{email_address}
        || $data->{username}
        || $data->{user_id};
    unless ( defined $user_id ) {
        $rest->header( -status => HTTP_400_Bad_Request );
        return "No email_address, username or user_id provided!";
    }
    my $user = eval { Socialtext::User->Resolve($user_id) };
    if ($@ or !defined $user) {
        $rest->header( -status => HTTP_400_Bad_Request );
        return "Could not resolve the user: $user_id";
    }

    if (! $account->has_user($user)) {
        eval { $account->add_user(user => $user) };
        if ( $@ ) {
            $rest->header( -status => HTTP_400_Bad_Request );
            return "Could not add user to the account: $@";
        }
    }

    $rest->header( -status => HTTP_201_Created );
    return '';
}

sub DELETE {
    my ( $self, $rest ) = @_;

    unless ($self->user_can('is_business_admin')) {
        $rest->header( -status => HTTP_401_Unauthorized );
        return '';
    }

    my $account = Socialtext::Account->new( 
        name => Socialtext::String::uri_unescape( $self->acct ),
    );
    unless ( defined $account ) {
        $rest->header( -status => HTTP_404_Not_Found );
        return "Could not find that account.";
    }

    my $user_id = $self->username;
    my $user = eval { Socialtext::User->Resolve($user_id) };
    if ($@ or !defined $user) {
        $rest->header( -status => HTTP_400_Bad_Request );
        return "Could not resolve the user: $user_id";
    }

    if ($user->primary_account->account_id == $account->account_id) {
        $rest->header( -status => HTTP_400_Bad_Request );
        return "Cannot remove a user from their primary account.";
    }

    my @roles = Socialtext::Account::Roles->RolesForUserInAccount(
        user => $user,
        account => $account,
        direct => "yes",
    );
    unless (@roles) {
        $rest->header( -status => HTTP_400_Bad_Request );
        return "User does not belong to this account.";
    }

    eval { $account->remove_user(user => $user) };
    if ( $@ ) {
        $rest->header( -status => HTTP_400_Bad_Request );
        return "Could not remove user from the account: $@";
    }

    $rest->header( -status => HTTP_204_No_Content );
    return '';
}

sub permission {
    +{ GET => 'is_business_admin' };
}

sub element_list_item {
   return "<li><a href=\"$_[1]->{uri}\">$_[1]->{name}<a/></li>\n";
}

sub get_resource {
    my $self = shift;
    my $rest = shift;

    my $account = Socialtext::Account->Resolve( $self->acct );
    
    unless ( defined $account ) {
       $rest->header(
           -status => HTTP_404_Not_Found,
        );
        return [];
    };

    return [
        map { $self->_user_representation( $_ ) }
            @{ $account->users_as_hash }
    ];
}

sub _user_representation {
    my $self      = shift;
    my $user_info = shift;

    return +{
        name => $user_info->{email_address},
        uri  => "/data/users/" . $user_info->{email_address},
    }
}

1;
