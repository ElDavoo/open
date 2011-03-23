# @COPYRIGHT@
package Socialtext::l10n;
use strict;
use warnings;
use base 'Exporter';

our @EXPORT_OK = qw(best_locale system_locale loc loc_lang );
our $CUR_LOCALE = 'en';
our $SYS_LOCALE = 'en';

sub loc {
    delete $INC{'Socialtext/l10n.pm'};
    no warnings 'redefine';
    local $SIG{__WARN__} = sub { 1 };
    require Socialtext::l10n;
    _rebind_overrides();
    *loc = \&Socialtext::l10n::loc;
    goto &Socialtext::l10n::loc;
}

sub _loc_lang {
    $CUR_LOCALE = shift if @_;
    return $CUR_LOCALE;
}

sub _best_locale {
    return loc_lang() || system_locale();
}

sub _system_locale {
    $SYS_LOCALE = shift if @_;
    return $SYS_LOCALE;
}

sub _rebind_overrides {
    *loc_lang = \&_loc_lang;
    *best_locale = \&_best_locale;
    *system_locale = \&_system_locale;
    *_ = \&loc;
}

_rebind_overrides();

1;
