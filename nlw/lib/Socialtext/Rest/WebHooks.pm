package Socialtext::Rest::WebHooks;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Rest::Entity';
use Socialtext::JSON qw/encode_json decode_json/;
use Socialtext::WebHook;
use Socialtext::Account;
use Socialtext::Workspace;
use Socialtext::Group;
use Socialtext::User;
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

    my %checkers = (
        account_id => sub {
            my $obj = shift;
            my $acct_id = $obj->{account_id} || return 0;
            my $acct = Socialtext::Account->new(account_id => $acct_id);
            return $acct && $acct->has_user($rest->user);
        },
        workspace_id => sub {
            my $obj = shift;
            my $wksp_id = $obj->{workspace_id} || return 0;
            my $wksp = Socialtext::Workspace->new(workspace_id => $wksp_id);
            return $wksp && $wksp->has_user($rest->user);
        },
        group_id => sub {
            my $obj = shift;
            my $group_id = $obj->{group_id} || return 0;
            my $group = Socialtext::Group->GetGroup(group_id => $group_id);
            return $group && $group->has_user($rest->user);
        },
        to_user => sub {
            my $obj = shift;
            my $user_id = $obj->{details}{to_user} || return 0;
            my $user = Socialtext::User->new(user_id => $user_id);
            return $user && $user->user_id == $rest->user->user_id;
        },
    );
    my %class_checks = (
        page   => [qw/account_id workspace_id/],
        signal => [qw/account_id group_id to_user/],
    );

    my $class = $object->{class};
    if (!$rest->user->is_business_admin) {
        my $allowed = 0;
        for my $class_prefix (keys %class_checks) {
            if ($class =~ m/^\Q$class_prefix\E\.\w+$/) {
                for my $param (@{ $class_checks{$class_prefix} }) {
                    next unless $checkers{$param}->($object);
                    $allowed = 1;
                    last;
                }
            }
        }
        return $self->not_authorized unless $allowed;
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
