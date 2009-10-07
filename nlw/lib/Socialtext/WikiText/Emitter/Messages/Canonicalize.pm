package Socialtext::WikiText::Emitter::Messages::Canonicalize;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::WikiText::Emitter::Messages::Base';
use Socialtext::l10n qw/loc/;
use Socialtext::WebHook;
use Readonly;

Readonly my %markup => (
    asis => [ '{{', '}}' ],
    b    => [ '*',  '*' ],
    i    => [ '_',  '_' ],
    del  => [ '-',  '-' ],
    a    => [ '"',  '"<HREF>' ],
);

sub msg_markup_table { return \%markup }

sub msg_format_unknown {
    my $self = shift;
    my $ast = shift;
    my $wafl = "{$ast->{wafl_type}: $ast->{wafl_string}}";

    Socialtext::WebHook->Filter(
        class => "wafl.canonicalize.$ast->{wafl_type}",
        ref => \$wafl,
    );

    return $wafl;
}

sub msg_format_link {
    my $self = shift;
    my $ast = shift;
    return "{$ast->{wafl_type}: $ast->{wafl_string}}"
}

sub msg_format_user {
    my $self = shift;
    my $ast = shift;
    if ($self->{callbacks}{decanonicalize}) {
        return $self->user_as_username( $ast );
    }
    else {
        return $self->user_as_id( $ast );
    }
}

sub user_as_id {
    my $self = shift;
    my $ast  = shift;

    my $user = eval{ Socialtext::User->Resolve( $ast->{user_string} ) };
    return loc('Unknown Person') unless $user;

    my $user_id = $user->user_id;
    return "{user: $user_id}";
}

sub user_as_username {
    my $self = shift;
    my $ast  = shift;
    my $account_id = $self->{callbacks}{account_id};

    my $user = $self->_ast_to_user($ast);
    return "{user: $ast->{user_string}}" unless $user;

    if ($user->primary_account_id == $account_id) {
        my $username = $user->username;
        return "{user: $username}";
    }
    else {
        return $user->best_full_name;
    }
}

sub _ast_to_user {
    my $self = shift;
    my $ast = shift;
    return eval{ Socialtext::User->Resolve( $ast->{user_string} ) };
}

1;
