package Socialtext::Rest::WebHooks;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Rest::Entity';
use Socialtext::JSON qw/encode_json decode_json/;
use Socialtext::WebHook;
use Socialtext::HTTP ':codes';

sub GET_json {
    my $self = shift;
    return $self->not_authorized unless $self->rest->user->is_business_admin;

    my $result = [];
    my $all_hooks = Socialtext::WebHook->All;
    for my $h (@$all_hooks) {
        push @$result, $h->to_hash;
    }
    return encode_json($result);
}

sub PUT_json {
    my $self = shift;
    my $rest = shift;

    my $content = $rest->getContent();
    my $object = decode_json( $content );
    if (ref($object) ne 'HASH') {
        $rest->header( -status => HTTP_400_Bad_Request );
        return 'Content should be a hash.';
    }

    my $class = $object->{class};
    if ($class =~ m/^page\.(\w+)$/) {
        if (my $acct_id = $object->{account_id}) {
            my $acct = Socialtext::Account->new(account_id => $acct_id);
            return $self->not_authorized
                unless $acct and $acct->has_user($rest->user);
        }
        elsif (my $wksp_id = $object->{workspace_id}) {
            my $wksp = Socialtext::Workspace->new(workspace_id => $wksp_id);
            return $self->not_authorized
                unless $wksp and $wksp->has_user($rest->user);
        }
        else {
            return $self->not_authorized unless $rest->user->is_business_admin;
        }
    }
    else {
        return $self->not_authorized unless $rest->user->is_business_admin;
    }

    my $hook;
    eval { 
        $object->{creator_id} = $rest->user->user_id;
        $object->{details_blob} = encode_json(delete($object->{details}) || {} );
        $hook = Socialtext::WebHook->Create(%$object),
    };
    if ($@) {
        warn $@;
        $rest->header( -status => HTTP_400_Bad_Request );
        return "$@";
    }

    $rest->header(
        -status => HTTP_201_Created,
        -Location => "/data/webhooks/" . $hook->id,
    );
    return '';
}

1;
