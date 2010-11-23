package Socialtext::l10n::I18N::xq;

use utf8;
use strict;
use warnings;
use base 'Locale::Maketext';

our %Lexicon = ( _AUTO => 1 );

sub maketext {
    my $self   = shift;
    my $result = "«".shift()."»";
    return $self->SUPER::maketext($result, @_);
}

1;
