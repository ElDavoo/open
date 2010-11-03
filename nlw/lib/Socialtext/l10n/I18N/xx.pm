package Socialtext::l10n::I18N::xx;
use base 'Locale::Maketext';

our %Lexicon = ( _AUTO => 1 );

sub maketext {
    my $self   = shift;
    my @tokens = split(/(<[^<]*|quant)/, shift);
    my $result = '';
    for my $token (@tokens) {
        unless ($token =~ /^(?:<|quant$)/) {
            $token =~ s/[[:upper:]]/X/g;
            $token =~ s/[[:lower:]]/x/g;
            $token =~ s/[[:digit:]]/0/g;
        }

        $result .= $token;
    }
    return $self->SUPER::maketext($result, @_);
}

1;
