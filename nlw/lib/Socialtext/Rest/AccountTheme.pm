package Socialtext::Rest::AccountTheme;
use Moose;
use Socialtext::Theme;
use Socialtext::Permission qw(ST_READ_PERM);
use Socialtext::JSON qw(encode_json);

extends 'Socialtext::Rest::Collection';

has 'account' => (is=>'ro', isa=>'Maybe[Socialtext::Account]', lazy_build=>1);
sub _build_account { Socialtext::Account->Resolve(shift->acct) };

sub GET_theme {
    my $self = shift;
    my $rest = shift;

    return $self->no_resource('account') unless $self->account;

    return $self->not_authorized()
        unless $self->account->user_can(
            user => $self->rest->user,
            permission => ST_READ_PERM,
        );

    my $prefs = $self->account->prefs->all_prefs;
    return encode_json($prefs->{theme});
}

1;
