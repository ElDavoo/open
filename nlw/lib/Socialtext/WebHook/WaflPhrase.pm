package Socialtext::WebHook::WaflPhrase;
# @COPYRIGHT@
use strict;
use warnings;
use Class::Field qw( const field);
use Socialtext::Formatter::WaflPhrase;
use base 'Socialtext::Formatter::WaflPhrase';
use Socialtext::Permission 'ST_READ_PERM';
use Socialtext::l10n qw( loc );
use Socialtext::WebHook;

field instance => undef;
field method => undef;
field wafl_id => 'webhook_waflphrase';

sub html {
    my $self = shift;
    return Socialtext::WebHook->Filter(
        class => "wafl.to-html." . $self->method,
        content => $self->wikitext,
    );
}


1;
